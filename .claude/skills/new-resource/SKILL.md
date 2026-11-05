---
name: new-resource
description: Create a new fivem-city script (resource) in server-data/resources/[local]/ following the project standards. Use when the user wants a new feature, job, system, command or script of our own (e.g. "make a fishing job", "create a script that...", "/new-resource").
---

# New resource

Builds a `city_<feature>` resource from the `city_base` template, written to `docs/standards/` (security, performance, code style). Read those three files before writing code; this skill is the checklist, they are the rules.

## 1. Pin down the feature

If the request is vague, ask (one AskUserQuestion, max 3-4 questions) only what changes the design: who can use it (everyone / job / admin), where (locations, ox_target on what), what it gives or costs, whether it saves data. Pick sensible defaults for the rest and say so.

Check it doesn't already exist: `docs/scripts/README.md` lists every script and `docs/scripts/issues.md` the known overlaps. If a Qbox script already does it, say so and offer to configure or patch that one instead (see the `patch-script` skill). If the user wants ours to **replace** an installed script (our own police, racing, phone), follow the `replace-script` skill alongside this one: it maps what the old script provides first and removes it in the same branch.

## 2. Scaffold

`server-data/resources/[local]/city_<feature>/` (lowercase snake_case, one feature per resource):

```
fxmanifest.lua
config.lua              everything a server owner might tune (coords as vector3/vector4, prices, cooldowns, item names, jobs)
client/main.lua
server/main.lua
server/config.lua       only for values players mustn't see (rewards, webhooks); server_scripts only
shared/*.lua            only if both sides need it
locales/en.json         once there are more than a handful of strings; use locale('key')
web/                    only if it has a NUI page (see section 4)
```

Split by topic (`client/zones.lua`, `server/shop.lua`) before any file passes ~300 lines.

`fxmanifest.lua`, in this order:

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'city_<feature>'
description 'One line about what it does'
version '0.1.0'

ox_lib 'locale'                     -- only with locales/

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',       -- only if it uses the database
    'server/main.lua',
}

files {
    'locales/*.json',               -- and any client module loaded with require, and web/ files
}

dependencies {
    'ox_lib',
    'qbx_core',
}
```

Modules loaded with `require` aren't listed as scripts (they'd run twice); client ones go in `files`.

## 3. Code patterns

**Server event / callback** (security standard: source, player, types, context, cooldown):

```lua
lib.callback.register('city_<feature>:<action>', function(source, spotId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end

    local spot = type(spotId) == 'number' and Config.Spots[spotId]
    if not spot then
        lib.print.warn(('Player %s sent an invalid spot: %s'):format(src, spotId))
        return false
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - spot.coords) > Config.MaxDistance then return false end
    -- cooldown keyed by src or citizenid, job/grade checks, then do the work and decide the reward here
end)
```

- Name events after the player action (`city_fishing:server:sellFish`), never `giveItem(item, count)`. Prices, rewards and item names come from config on the server.
- Items: `exports.city_inventory:AddItem(src, name, count, metadata)`, `RemoveItem`, `GetItemCount`, `CanCarryItem`, `Search` (same API as ox_inventory). Usable items: `exports.qbx_core:CreateUseableItem(name, function(source, item) end)`. New items: use the `add-item` skill.
- Money: `exports.qbx_core:GetMoney(src, 'cash')`, `RemoveMoney`, `AddMoney`.
- Database: oxmysql with `?` parameters only. Create tables with `CREATE TABLE IF NOT EXISTS` at start (see `city_inventory/server/storage.lua`), or ship a `.sql` and add it to `scripts/import-sql.sh`.

**Admin command**:

```lua
lib.addCommand('<name>', {
    help = locale('command_<name>'),
    params = { { name = 'id', type = 'playerId', help = locale('param_id') } },
    restricted = 'group.admin',
}, function(source, args)
    -- source 0 = server console
    if source ~= 0 and not exports.qbx_core:IsOptin(source) then
        return exports.qbx_core:Notify(source, locale('not_on_duty'), 'error')
    end
end)
```

**Client**:
- Interactions with `exports.ox_target` (`addBoxZone`, `addSphereZone`, `addModel`, `addGlobalPlayer`) or `lib.points` / `lib.zones`; never a `while true do Wait(0)` distance loop.
- `cache.ped`, `cache.vehicle`, `cache.coords`; `lib.onCache` for changes.
- `lib.requestModel` / `lib.requestAnimDict`, then `SetModelAsNoLongerNeeded` / `RemoveAnimDict`.
- Clean up on stop: `AddEventHandler('onResourceStop', function(resource) if resource ~= cache.resource then return end ... end)` removes entities, blips, zones, target options.
- `[local]` resources start after ox_target in `server.cfg`, but `city_inventory` and anything ensured before it must wait for `GetResourceState('ox_target') == 'started'` (see `city_inventory/client/shops.lua`).
- Player-loaded hook: `RegisterNetEvent('QBCore:Client:OnPlayerLoaded', ...)`.

## 4. NUI page (only if it has one)

- Plain HTML/CSS/JS in `web/`, ES modules (`<script type="module">`), no build step. Set text with `textContent`, never `innerHTML` with game data.
- Look: send `require '@city_ui.theme'` to the page on setup and apply it as CSS variables (copy `applyTheme` from `city_inventory/web/js/util.js`); match the inventory (dark see-through panels, `--radius-large`, pill tabs). Never hard-code theme colors and **never use `backdrop-filter`** (FiveM's NUI draws it black); for blur use `TriggerScreenblurFadeIn/Out` from Lua.
- Validate every NUI callback on the server like a net event.
- Preview it in Chrome the way the `ship` skill describes before calling it done.

## 5. Finish

1. Unit tests for plain-Lua logic: `tests/city_<feature>/` with a `harness.lua` (copy `tests/city_inventory/harness.lua` and trim it) and one file per area; `scripts/check.sh` picks them up.
2. Run the review checklists at the end of each file in `docs/standards/` and fix what fails.
3. `bash scripts/check.sh` must pass.
4. Add the resource to the "Ours" table in `docs/scripts/README.md`; update `CLAUDE.md` only if it changes architecture (load order, a new shared convention).
5. Tell the user how to test it in game: `git pull` on the server PC, `ensure city_<feature>` in the txAdmin console, then the exact steps. Use the `ship` skill to commit when they ask.
