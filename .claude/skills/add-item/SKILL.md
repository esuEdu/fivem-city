---
name: add-item
description: Add or change an item, weapon, ammo, attachment, crafting recipe, test kit or shop entry in city_inventory (data/items.lua, data/weapons.lua, data/shops.lua, config.lua). Use when the user wants a new item, wants an item usable, wants something sold in a shop or craftable ("add a burger item", "sell X in the 24/7", "/add-item").
---

# Add an item (or put it in a shop)

All item data lives in `server-data/resources/[local]/city_inventory/`. **`data/*.lua` must stay plain data**: qbx_core loads `data/items.lua` and `data/weapons.lua` too, so no functions calling natives, no `Config`, no `require`.

## Regular item: `data/items.lua`

Keep the file's style (4 spaces, keys in quotes, `category` right after `label`):

```lua
    ['fishing_rod'] = {
        label = 'Fishing Rod',
        category = 'tool',
        weight = 1500,            -- grams
        stack = false,            -- default true
        close = true,             -- close the inventory when used (default true)
        description = 'For catching fish',
    },
```

- **Name**: lowercase snake_case. Lookups are case-insensitive, but the name is stored as written.
- **category**: one of `Config.Categories` in `config.lua` (weapon, ammo, food, drink, medical, drug, tool, electronics, valuable, material, document, misc). A new category goes in `Config.Categories` with a label and a color; it becomes a filter tab and the slot gradient.
- **Image**: `web/images/<name>.png` (lowercase, square PNG with a transparent background, ~100-200px). If the picture has another name, set `client = { image = 'other.png' }`. The images from qbx_invimages are already there: check before asking for one.

## Making it usable

Pick one:

- **Simple effects, data only** (ox_inventory style), in `client`:
  ```lua
  client = {
      status = { hunger = 200000, thirst = -50000 },  -- ox/ESX scale (1,000,000 = 100%), applied with SetMetadata
      usetime = 2500,                                  -- progress bar in ms
      anim = 'eating', prop = 'burger',                -- presets in client/use.lua, or { dict, clip } / { model, pos, rot }
      notification = 'You feel better',
  },
  ```
  Items with `status` or `usetime` use up 1 by default; set `consume = 0` to keep it, or another number.
- **Custom logic**: in the resource that owns the feature (server side), `exports.qbx_core:CreateUseableItem('name', function(source, item) ... end)`. Return `false` to say it wasn't used (nothing consumed). This always wins over the data fields.
- **Client event**: `client = { event = 'resource:client:use' }` fires that event on the client only, with `(definition, { name, slot, metadata })`, no server step (how the radio works). Only for things that give nothing of value.

⚠️ Food, drinks, alcohol, joints and coke are also defined by `qbx_smallresources/qbx_consumables` (`CreateUseableItem`), which wins over our `client.status`. To change those, change that config, or patch it (see `docs/scripts/issues.md`).

## Weapons, ammo, attachments: `data/weapons.lua`

- `Weapons['WEAPON_X'] = { label, weight, ammoname = 'ammo-9', clip = 12 }` (`clip` optional, else the game's magazine size). The name must be the GTA weapon name.
- `Ammo['ammo-x'] = { label, weight }`.
- `Components['at_x'] = { label, weight, type = 'muzzle', client = { component = { \`COMPONENT_...\` } } }`; one attachment per `type` on a gun.

## Shops: `data/shops.lua`

Add to an existing shop's `inventory`, or a new shop:

```lua
    { name = 'fishing_rod', price = 250 },                       -- price 0 = free
    { name = 'WEAPON_PISTOL', price = 1000, license = 'weapon', metadata = { registered = true } },
    { name = 'bait', price = 2, count = 50 },                    -- limited stock, refills on restart
    { name = 'lockpick', price = 500, currency = 'black_money' },
    { name = 'radio', price = 0, grade = 2 },                    -- job grade, for shops with groups
```

New shop: a key with `name`, `inventory`, and either `locations = { vec3(...) }` (ox_target sphere + optional `blip = { id, colour, scale }`) or `model = { \`prop\` }`; `groups = { police = 0 }` limits it to a job. Shops a script registers itself use `exports.ox_inventory:RegisterShop(type, data)` and `openInventory('shop', { type, id })`.

## Recipes and kits: `config.lua`

- `Config.Recipes`: `{ ingredients = { { 'a', 1 }, { 'b', 2 } }, result = { 'c', 1 }, duration = 3000 }`. Dragging any two ingredients onto each other starts it.
- `Config.Kits`: test item sets for the `/kit` admin command.

## Check and test

1. `bash scripts/check.sh` (syntax, and the tests load every item and shop: a shop item that doesn't exist fails `tests/city_inventory/shops.lua`).
2. In game (server PC): `git pull`, `ensure city_inventory`, `/optin`, then `/giveitem <your id> <item> <count>`; for shops walk to it and buy; for recipes `/giveitem` the ingredients and drag one onto the other.
3. Commit with the `ship` skill when the user asks.
