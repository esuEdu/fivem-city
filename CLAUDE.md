# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A FiveM (GTA V) roleplay server on the **Qbox** framework (`qbx_core`) with the scripts of the Qbox txAdmin recipe (jobs, garages, HUD, illenium-appearance, npwd phone, …), the **ox** stack (oxmysql, ox_lib, ox_target, ox_doorlock, ox_fuel), our own inventory `city_inventory` (replaces ox_inventory) and pma-voice. All code is Lua 5.4 resources loaded by FXServer; there is no build step. `bash scripts/check.sh` checks our `[local]` resources without a server (Lua syntax, UI JavaScript, locale JSON, and the plain-Lua unit tests in `tests/<resource>/`, run with luajit); the rest is verified by restarting the resource on a running server.

## Running the server

FXServer is x86_64 only and **does not run on Apple Silicon** (crashes under Rosetta and QEMU). On a Mac, edit resources here and run the server on an x86_64 Windows/Linux machine.

```sh
cp .env.example .env                 # set CFX_LICENSE_KEY and MYSQL_ROOT_PASSWORD (alphanumeric only)
docker compose up -d --build         # FXServer + txAdmin, and MariaDB
docker compose logs fxserver | grep -i pin   # txAdmin PIN, then http://localhost:40120
docker compose logs -f fxserver
docker compose restart fxserver
docker compose build --no-cache fxserver && docker compose up -d   # update FXServer build
```

In the txAdmin wizard choose **Existing Server Data** → `/server-data`, config `server.cfg` — not a recipe, which installs its own copy under `/txData` that ignores this repo. txAdmin starts the server (the image entrypoint has no `+exec`).

Docker only imports `qbx_core.sql` into a new database. Create the other resources' tables with `scripts/import-sql.sh` (safe to re-run; run it after adding resources that bring SQL).

After editing a resource, reload it from the txAdmin console or in-game: `ensure <resource_name>` (or `restart`).

The full run guide (setup, updates, backups, troubleshooting) is `docs/docker.md`; keep it in step with changes to the Docker setup.

## Architecture

- **`server-data/server.cfg`** is the single entry point. It `exec`s `secrets.cfg`, then `ensure`s core resources in a fixed order (`oxmysql` → `ox_lib` → `qbx_core` → `city_ui` → `city_inventory` → `ox_inventory` → `ox_target`), then whole groups: `[ox]`, `[qbx]`, `[standalone]`, `[voice]`, `[assets]`, `[npwd-apps]`, then `qbx_npwd`, `npwd`, `[maps]`, `[local]`. Convars follow the Qbox recipe's `server.cfg` / `ox.cfg` / `voice.cfg`. Dropping a resource into one of those group folders is enough to start it. Framework/inventory convars (`qbx:enableBridge`, `inventory:framework "qbx"`, `inventory:accounts` left unset so it defaults to `["money"]`: the cash item is the player's cash) and ACE permissions (`group.admin` > `group.mod` > `group.support`) are also set there.
- **Secrets**: `secrets.cfg` is gitignored. In Docker, `docker/fxserver/entrypoint.sh` regenerates it on every start from env vars (license key, `mysql_connection_string` pointing at host `mariadb`). If `CFX_LICENSE_KEY` is empty, an existing mounted `secrets.cfg` is used instead.
- **Docker**: `docker-compose.yml` is the only way the server is run. It bind-mounts `./server-data` into the container, so the server runs the repo's files (FXServer itself is downloaded inside the image, never from `artifacts/` — Windows filesystems break its symlinks). MariaDB imports `qbx_core/qbx_core.sql` only when its volume is first created.
- **Third-party resources are vendored** (committed). `scripts/install-resources.sh` re-downloads everything the Qbox txAdmin recipe (`qbox.yaml`) installs except ox_inventory, wiping each target folder first, copies the qbx_invimages item images into `city_inventory/web/images`, then applies `scripts/patches/<resource>.patch`. Don't hand-edit those resources without a patch, or the change is lost on the next update: edit, then `bash scripts/make-patch.sh "server-data/resources/[group]/<resource>"`, which rebuilds the resource's whole patch from upstream (a bare `git diff` would drop the existing patch's changes).
- **`city_inventory`** (`[local]/`) replaces ox_inventory. qbx_core is hard-wired to ox_inventory, so `scripts/patches/qbx_core.patch` points it at `city_inventory`, which provides the same server/client export names and arguments (`AddItem`, `RemoveItem`, `GetItemCount`, `Search`, …) and the same `data/items.lua` / `data/weapons.lua` format (qbx_core loads those files too, so they must stay plain data). Make items usable with `exports.qbx_core:CreateUseableItem`. Inventories are saved in the `city_inventories` table, keyed by citizenid. `data/items.lua` is Qbox's item list; its ox-style `client.status/anim/prop/usetime/event/add/remove` fields work (`server/use.lua`, `client/use.lua`). Item names are case-insensitive (`WEAPON_PISTOL` = `weapon_pistol`) and stored as written in `data/`. Dropping one item onto another combines them on the server (`server/actions.lua` `combine`): ammo loads a gun, an attachment goes on a gun (kept in `metadata.components`), and `Config.Recipes` pairs craft; a gun's weight includes its attachments and loaded rounds (`shared/weight.lua`).
- **`ox_inventory`** (`[local]/`) is a stand-in, not the real resource: it satisfies scripts that check for ox_inventory and forwards its exports to `city_inventory` (`server/compat.lua`, `client/compat.lua` hold the extra ones and fire ox's events like `ox_inventory:currentWeapon` / `itemCount`). Stashes work (`RegisterStash`, `openInventory('stash')`, `forceOpenInventory`, `registerHook('openInventory')`; `server/stashes.lua`, shown as a second panel and saved in `city_inventories` as `stash:<id>`). Shops work too: `data/shops.lua` (ox_inventory's default stores, with blips and ox_target zones from `client/shops.lua`) plus `RegisterShop` from scripts (ambulance armory); items are bought by dragging them out of the shop panel, paid from `Config.ShopAccounts` or an item `currency`, with licence/grade/stock checked in `server/shops.lua`. Ground drops (`server/drops.lua`, bags from `client/drops.lua`, in memory for `Config.DropMinutes`; `CustomDrop`/`CreateDropFromPlayer`) and player trades (`server/trades.lua`: ox_target "Trade" on a player, both offers held aside as small inventories until both accept) work too; `server/other.lua` keeps one of stash/shop/ground/trade/search open per player. Trunks and gloveboxes are stashes keyed by plate (`server/vehicles.lua`, sizes in `Config.VehicleStorage`; saved only for cars in `player_vehicles`), opened with TAB at a car's back or inside it. Searching players (`openNearbyInventory`, `openInventory('player', id)`; `server/searches.lua`) shows the target's inventory as the second panel: police on duty (`Config.SearchJobTypes`) search anyone close, anyone may rob a player who is cuffed, down or has `state.handsup`, and staff with `Config.SearchStaffAce` on admin duty open anyone's from anywhere. The `money` item (`Config.CashItem`) **is** the player's cash: qbx_core mirrors city_economy's cash balance into it, scripts add or take it through qbx money (`server/cash.lua`), and every move inside the inventory (ground, trade offers, stashes, trunks, another player, death drop, clearing, expiry) is written to the ledger first by `server/cashflow.lua` (the hook in `Inventory.transfer`; if the ledger refuses, the item does not move). Scripts can't add/remove/set cash in stashes, drops or trades, and `players.sync` puts a pocket back to the ledger value (with a flag) if they ever differ.
- **`city_economy`** (`[local]/`) owns all money: an append-only double-entry ledger (`economy_accounts`, `economy_ledger`) with atomic, locked postings. `qbx_core`'s `AddMoney` / `RemoveMoney` / `SetMoney` for `cash` and `bank` ask it first (`scripts/patches/qbx_core.patch`) and `PlayerData.money` is only a mirror (`SetPlayerData('money')` is refused, `crypto` is gone). It only accepts the resource + reason pairs listed in `city_economy/server/config.lua` `sources`; anything else is refused and logged, so a script that pays or charges must pass a reason and be added there. New characters get $2,000 cash and $18,000 bank from it. Rules and design: `PROMPT_ECONOMIA_FIVEM.md`, `BANCO_DESIGN.md`; blocked scripts are listed in `docs/scripts/issues.md`. **`city_bank`** is the bank on top of it: branches (banker NPC, fingerprint, panel with accounts, cards, transfers, loans, bills, history, staff tab), ATMs, the `bank_card` and `pos_terminal` items and a scheduler (bills, card cycles, installments, savings yield). It moves money only through `city_economy` `Bank*` exports (reasons `bank-...`, callable only from city_bank); rules and numbers are in `city_bank/server/config.lua`. Renewed-Banking was removed.
- **`city_os`** (`[local]/`) is the iFruit tablet (`tablet` item, F2): lock screen, passcode, home, dock, notification center and the built-in Settings, and nothing else. Every app is its own resource: it registers on the server with `exports.city_os:RegisterApp` (glyph + colors icon, its own `web/` page loaded in an iframe, access by job/gang/staff/unlock), styles its page with `city_os/web/kit/kit.css` + `kit.js`, and uses `Notify`/`SetBadge`/`Unlock`; its own server events still check access. Tablet settings and the bcrypt passcode are saved per serial in `city_os_tablets`; a player's own wallpaper link stays in client KVP. Design: `docs/city-os.md`.
- **`city_staff`** (`[local]/`) is the first tablet app, **Staff**, and replaced qbx_adminmenu: player list and actions, `/report` reports, warnings (`city_staff_warnings`), bans (qbx_core's `bans` table), the staff log (`city_staff_log`), noclip/names/blips and vehicles. Staff tools live only in the app, with no in-game commands; `qbx_core.patch` also removes qbx_core's admin commands and turns admin duty off (`requireOptIn = false`, no `/optin`, so `IsOptin` is always true). Levels are the `support` < `mod` < `admin` ACEs; what each may do is `Config.Permissions`, checked by every server callback (`server/staff.lua` `staff.register`). Design: `docs/city-staff.md`.
- **`city_ui`** (`[local]/`) holds the shared look of every screen in `theme.lua` (accent yellow, panel colors, radius, fonts). Resources load it with `require '@city_ui.theme'`, send it to their NUI page, and the page turns each key into a CSS variable (`accentText` → `--accent-text`); see `city_inventory/web/js/util.js` `applyTheme`. Don't hard-code those colors in a page's CSS, and don't use `backdrop-filter`: FiveM's NUI can't blur the game behind the page and draws it black.

## Writing our own resources

Custom code lives in `server-data/resources/[local]/` (`city_base` is the starter template; `city_inventory/server/commands.lua` has example admin commands). Conventions used there:

- `fxmanifest.lua` with `fx_version 'cerulean'`, `game 'gta5'`, `lua54 'yes'`, `@ox_lib/init.lua` as a shared script, and `dependencies { 'ox_lib', 'qbx_core' }`. Layout: `config.lua`, `client/main.lua`, `server/main.lua`.
- Use ox_lib helpers (`lib.addCommand`, `lib.notify`, `lib.print`, `cache.ped` / `cache.vehicle`) and Qbox exports (`exports.qbx_core:Notify`, `IsOptin`, …).
- Staff tools go in the Staff app (`city_staff`), not in-game commands. Test/dev commands that remain use `restricted = 'group.admin'` (the `IsOptin` check they still call is always true now that admin duty is off), with `source == 0` allowed for the server console.
- Net events are namespaced `<resource>:client:<name>` / `<resource>:server:<name>`. The player-loaded hook is `QBCore:Client:OnPlayerLoaded` (via the Qbox bridge).
- Qbox scripts (`qbx_*`) go in `[qbx]/`, framework-independent third-party scripts in `[standalone]/`, MLOs/map edits in `[maps]/`.

## Standards

All code in `[local]/` must follow these, and every branch and commit follows `git.md`. Run through each checklist before calling the work done.

@docs/standards/security.md
@docs/standards/performance.md
@docs/standards/code-style.md
@docs/standards/git.md

## Skills

Project skills in `.claude/skills/` hold the step-by-step workflows: `new-resource` (a new `city_<feature>` script), `add-item` (items, weapons, shops, recipes), `patch-script` (changing a vendored script), `replace-script` (our resource replacing a vendored one, which is then removed everywhere) and `ship` (checks, NUI preview, commit, in-game test steps). Keep them in step when these workflows change.

`docs/skills.md` lists every skill (ours and not ours) with its name, description and location. As soon as someone starts a new skill, or renames, moves or removes one, run the `skill-registry` agent (`.claude/agents/skill-registry.md`) so the list stays complete.
