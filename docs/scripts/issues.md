# Script issues and overlaps

Scripts that need changes because the server uses `city_inventory` instead of ox_inventory, and features that exist twice. See [README.md](README.md) for what each script does.

## 1. Scripts that need fixing because of ox_inventory

### Broken or partly broken

None known.

### Fixed in `city_inventory`

- **EMS shops:** our **Medicine Cabinet** stood 3 m from qbx_ambulancejob's free **Armory** at Pillbox; it's removed from `data/shops.lua`.
- **ox_fuel:** pays with a **"money" item**; `city_inventory` treats that item as the player's qbx cash (`server/cash.lua`, `Config.CashItem`).
- **qbx_police** (radial **Search** and **Rob**, via `openNearbyInventory`) and **qbx_adminmenu** (**Open inventory**, via `openInventory('player', id)`): player search (`server/searches.lua`).

### Already patched

- **qbx_core:** uses `city_inventory` (`scripts/patches/qbx_core.patch`).
- **qbx_radialmenu:** the dead **Give Contact Details** button is removed (`scripts/patches/qbx_radialmenu.patch`).
- **qbx_police:** registers its locker and trash stashes on start, and **Rob** accepts the hands-up key's animation (scully_emotemenu's `random@mugging3`), not only the emote's (`scripts/patches/qbx_police.patch`).

### Working through the `ox_inventory` stand-in (nothing to do)

illenium-appearance, mm_radio, ox_doorlock, ox_target, qbx_ambulancejob, qbx_bankrobbery, qbx_houserobbery, qbx_jewelery, qbx_storerobbery, qbx_truckrobbery, qbx_drugs, qbx_weed, qbx_mechanicjob, qbx_taxijob, qbx_vineyard, qbx_recyclejob, qbx_scrapyard, qbx_diving, qbx_divegear, qbx_idcard, qbx_npwd, qbx_pawnshop, qbx_seatbelt, qbx_vehiclekeys, qbx_fireworks, qbx_smallresources, xt-prison.

The stand-in has to stay: about 40 scripts call `exports.ox_inventory`, ox_fuel checks for ox_inventory 2.30.0 by name, and qbx_ambulancejob and ox_fuel list it as a dependency.

## 2. Things that exist twice or overlap

| What | Where | Problem |
|---|---|---|
| **Trade on F6** | Unknown | Nothing in our scripts is bound to F6. Need to find what opens. |
| **Eating and drinking** | `qbx_smallresources/qbx_consumables` and `city_inventory/data/items.lua` (`client.status`) | Not a duplicate: no item is in both. qbx_consumables does sandwich, coffee, beer, vodka, whiskey (stress relief, drunk effect) and the drugs; `items.lua` does burger, sprunk, water and mustard. Its config also lists tosti, twerks_candy, snikkel_candy, water_bottle and kurkakola, which aren't items (harmless). Using either kind takes one item. |
| **Clothing on/off** | qbx_radialmenu **Clothing** and illenium-appearance | Two ways to take clothes off; inventory clothing slots would make three. |
| **Opening a trunk** | qbx_radialmenu **Vehicle Doors → Trunk** and TAB at the back of a car | Both open the lid. Harmless. |
| **Giving items as admin** | `/giveitem` and `/kit` (city_inventory), qbx_adminmenu **Give Item** | Not a duplicate: the admin menu runs our `/giveitem`. |
