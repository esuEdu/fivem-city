# Code style standards

Rules for code in `server-data/resources/[local]/`. When in doubt, match `city_base` and `city_troll`.

## Resource layout

```
city_<feature>/
  fxmanifest.lua
  config.lua          shared settings (only if the resource has any)
  client/main.lua
  server/main.lua
  shared/*.lua        helpers used by both sides (only if needed)
  locales/en.json     player-facing text, when there is enough of it
```

- Name resources `city_<feature>` in lowercase snake_case (`city_fishing`, `city_mechanic`). One feature per resource.
- Split big files by topic (`client/zones.lua`, `server/shop.lua`) and list them in `fxmanifest.lua`; no files over ~300 lines.
- `fxmanifest.lua`: `fx_version 'cerulean'`, `game 'gta5'`, `lua54 'yes'`, then `name`, `description`, `version`, then `shared_scripts` (with `'@ox_lib/init.lua'` first), `client_scripts`, `server_scripts`, `dependencies`.
- Server-only settings (webhooks, reward tables you don't want players to see) go in `server/config.lua`, listed under `server_scripts` only.

## Formatting

- 4 spaces, no tabs. Single quotes for strings. Trailing commas in multi-line tables.
- One statement per line; no semicolons.
- Format strings with `('%s has %d'):format(name, n)`, not `..` chains for more than two parts.
- Blank line between functions and between logical blocks.

## Naming

| Thing | Style | Example |
| --- | --- | --- |
| Local variables, functions | camelCase | `local playerCoords`, `local function getShop(id)` |
| Constants | UPPER_SNAKE_CASE | `local MAX_FORCE = 200` |
| Config table | `Config` with PascalCase keys | `Config.CityName`, `Config.Shops` |
| Net events | `<resource>:<client\|server>:<action>` | `city_troll:client:launch` |
| Callbacks | `<resource>:<action>` | `city_fishing:getCatch` |
| Exports | PascalCase | `exports.city_fishing:GetRodLevel(src)` |
| Commands | lowercase, short | `/launch` |

## Lua

- Everything is `local`. The only global per resource is `Config` (and `lib` / `cache` / `MySQL` from the included libraries).
- Return early instead of nesting `if` blocks; check failures first.
- Capture `local src = source` at the top of server handlers before any `Wait` or callback.
- Use ox_lib instead of writing your own: `lib.addCommand`, `lib.callback`, `lib.notify`, `lib.points`, `lib.zones`, `lib.progressBar`, `lib.inputDialog`, `lib.registerContext`, `lib.print.*` for logging (not `print`).
- Use Qbox exports (`exports.qbx_core:GetPlayer`, `Notify`, `IsOptin`, …) and ox_inventory exports for items. Use the `QBCore:` events only where Qbox has no native alternative.
- Use `vector3` / `vector4` for coords in config and code, not `{ x =, y =, z = }` tables.
- Use backtick hashes for models known in advance (`` `adder` ``) instead of `joaat('adder')` at runtime.

## Text and config

- Everything a server owner might tune (coords, prices, cooldowns, item names, job names) goes in `config.lua`, not inline.
- Player-facing text is English and short. Once a resource has more than a handful of strings, move them to `locales/en.json` and use `locale('key')` from ox_lib (`lib.locale()` at the top of the shared script).

## UI

- NUI pages take their colors, radius and fonts from `city_ui/theme.lua` (`require '@city_ui.theme'`, sent to the page and applied as CSS variables), so every screen looks like part of one set. Only page-specific values (sizes, layout) live in the page's own CSS.
- Plain HTML/CSS/JS, no build step. Set text with `textContent`, never `innerHTML` with game data.

## Comments

- Comment *why*, not *what*. One short line above the code it explains, as in `city_troll` (`-- source 0 = server console`).
- No commented-out code and no banner comments. Put a one-line `description` in `fxmanifest.lua` instead of a header comment.

## Review checklist

- [ ] Resource named `city_<feature>` with the standard layout and manifest order.
- [ ] No globals besides `Config`; all helpers are `local`.
- [ ] Event, callback and export names follow the table above.
- [ ] Tunable values are in `config.lua`; secrets in a server-only config.
- [ ] Uses ox_lib / Qbox / ox_inventory APIs instead of custom equivalents.
- [ ] 4-space indent, single quotes, trailing commas.
