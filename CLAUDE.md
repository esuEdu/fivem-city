# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A FiveM (GTA V) roleplay server on the **Qbox** framework (`qbx_core`) with the scripts of the Qbox txAdmin recipe (jobs, garages, HUD, illenium-appearance, npwd phone, …), the **ox** stack (oxmysql, ox_lib, ox_target, ox_doorlock, ox_fuel), our own inventory `city_inventory` (replaces ox_inventory) and pma-voice. All code is Lua 5.4 resources loaded by FXServer; there is no build step, linter or test suite. Changes are verified by restarting the resource on a running server.

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

Build/push the prebuilt image (used by `deploy/` on another PC):
```sh
docker buildx build --platform linux/amd64 -f docker/fxserver/Dockerfile -t ghcr.io/esuedu/fivem-city:latest --push .
```

## Architecture

- **`server-data/server.cfg`** is the single entry point. It `exec`s `secrets.cfg`, then `ensure`s core resources in a fixed order (`oxmysql` → `ox_lib` → `qbx_core` → `city_ui` → `city_inventory` → `ox_inventory` → `ox_target`), then whole groups: `[ox]`, `[qbx]`, `[standalone]`, `[voice]`, `[assets]`, `[npwd-apps]`, then `qbx_npwd`, `npwd`, `[maps]`, `[local]`. Convars follow the Qbox recipe's `server.cfg` / `ox.cfg` / `voice.cfg`. Dropping a resource into one of those group folders is enough to start it. Framework/inventory convars (`qbx:enableBridge`, `inventory:framework "qbx"`, `inventory:accounts "[]"` so money stays in qbx_core) and ACE permissions (`group.admin` > `group.mod` > `group.support`) are also set there.
- **Secrets**: `secrets.cfg` is gitignored. In Docker, `docker/fxserver/entrypoint.sh` regenerates it on every start from env vars (license key, `mysql_connection_string` pointing at host `mariadb`). If `CFX_LICENSE_KEY` is empty, an existing mounted `secrets.cfg` is used instead.
- **Two compose files**: root `docker-compose.yml` is local dev and bind-mounts `./server-data` into the container (FXServer itself is downloaded inside the image, never from `artifacts/` — Windows filesystems break its symlinks). `deploy/docker-compose.yml` runs the published image with `server-data` baked in; changes made inside that container are lost on update. Both import `qbx_core/qbx_core.sql` into MariaDB only when the DB volume is first created.
- **Third-party resources are vendored** (committed). `scripts/install-resources.sh` re-downloads everything the Qbox txAdmin recipe (`qbox.yaml`) installs except ox_inventory, wiping each target folder first, copies the qbx_invimages item images into `city_inventory/web/images`, then applies `scripts/patches/<resource>.patch`. Don't hand-edit those resources: put the change in a patch (edit, then `git diff -- <resource folder> > scripts/patches/<resource>.patch`), or it gets lost on the next update.
- **`city_inventory`** (`[local]/`) replaces ox_inventory. qbx_core is hard-wired to ox_inventory, so `scripts/patches/qbx_core.patch` points it at `city_inventory`, which provides the same server/client export names and arguments (`AddItem`, `RemoveItem`, `GetItemCount`, `Search`, …) and the same `data/items.lua` / `data/weapons.lua` format (qbx_core loads those files too, so they must stay plain data). Make items usable with `exports.qbx_core:CreateUseableItem`. Inventories are saved in the `city_inventories` table, keyed by citizenid. `data/items.lua` is Qbox's item list; its ox-style `client.status/anim/prop/usetime/event/add/remove` fields work (`server/use.lua`, `client/use.lua`). Item names are case-insensitive (`WEAPON_PISTOL` = `weapon_pistol`) and stored as written in `data/`.
- **`ox_inventory`** (`[local]/`) is a stand-in, not the real resource: it satisfies scripts that check for ox_inventory and forwards its exports to `city_inventory` (`server/compat.lua`, `client/compat.lua` hold the extra ones and fire ox's events like `ox_inventory:currentWeapon` / `itemCount`). Stashes, shops and drops (`RegisterStash`, `RegisterShop`, `CustomDrop`, `openInventory('stash')`, …) aren't built yet: they log a warning, so police lockers, the ambulance armory, mechanic and property storage don't open.
- **`city_ui`** (`[local]/`) holds the shared look of every screen in `theme.lua` (accent yellow, panel colors, blur, radius, font). Resources load it with `require '@city_ui.theme'`, send it to their NUI page, and the page turns each key into a CSS variable (`accentText` → `--accent-text`); see `city_inventory/web/app.js` `applyTheme`. Don't hard-code those colors in a page's CSS.

## Writing our own resources

Custom code lives in `server-data/resources/[local]/` (`city_base` is the starter template, `city_troll` an example admin command). Conventions used there:

- `fxmanifest.lua` with `fx_version 'cerulean'`, `game 'gta5'`, `lua54 'yes'`, `@ox_lib/init.lua` as a shared script, and `dependencies { 'ox_lib', 'qbx_core' }`. Layout: `config.lua`, `client/main.lua`, `server/main.lua`.
- Use ox_lib helpers (`lib.addCommand`, `lib.notify`, `lib.print`, `cache.ped` / `cache.vehicle`) and Qbox exports (`exports.qbx_core:Notify`, `IsOptin`, …).
- Admin commands use `restricted = 'group.admin'` and also require Qbox admin duty (`exports.qbx_core:IsOptin(source)`), with `source == 0` allowed for the server console.
- Net events are namespaced `<resource>:client:<name>` / `<resource>:server:<name>`. The player-loaded hook is `QBCore:Client:OnPlayerLoaded` (via the Qbox bridge).
- Qbox scripts (`qbx_*`) go in `[qbx]/`, framework-independent third-party scripts in `[standalone]/`, MLOs/map edits in `[maps]/`.

## Standards

All code in `[local]/` must follow these. Run through each checklist before calling the work done.

@docs/standards/security.md
@docs/standards/performance.md
@docs/standards/code-style.md
