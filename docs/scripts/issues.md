# Script issues and overlaps

Scripts that need changes because the server uses `city_inventory` instead of ox_inventory, and features that exist twice. See [README.md](README.md) for what each script does.

## 1. Scripts that need fixing because of ox_inventory

### Broken or partly broken

| Script | Problem | What to do |
|---|---|---|
| **ox_fuel** | Pays for fuel and jerry cans by taking a **"money" item** from the inventory (`server.lua` `defaultPaymentMethod`, `client/utils.lua`). The Qbox recipe kept that item synced with cash (`inventory:accounts ["money"]`); we keep money only in qbx_core, so the pump likely says "not enough money". | In `city_inventory`, treat the `money` item as the player's qbx cash (count, remove, add). Also covers any other script using it. |
| **qbx_police** | The radial menu's **Search** (police) and **Rob** (citizen) call `openNearbyInventory`, which isn't built: nothing happens. | Build player search. |
| **qbx_adminmenu** | **Open inventory** on a player calls `openInventory('player', id)` for someone else, which isn't built: nothing happens. | Comes with player search. |

### Already patched

- **qbx_core:** uses `city_inventory` (`scripts/patches/qbx_core.patch`).
- **qbx_police:** registers its locker and trash stashes on start (`scripts/patches/qbx_police.patch`).

### Working through the `ox_inventory` stand-in (nothing to do)

illenium-appearance, mm_radio, ox_doorlock, ox_target, qbx_ambulancejob, qbx_bankrobbery, qbx_houserobbery, qbx_jewelery, qbx_storerobbery, qbx_truckrobbery, qbx_drugs, qbx_weed, qbx_mechanicjob, qbx_taxijob, qbx_vineyard, qbx_recyclejob, qbx_scrapyard, qbx_diving, qbx_divegear, qbx_idcard, qbx_npwd, qbx_pawnshop, qbx_seatbelt, qbx_vehiclekeys, qbx_fireworks, qbx_smallresources, xt-prison.

The stand-in has to stay: about 40 scripts call `exports.ox_inventory`, ox_fuel checks for ox_inventory 2.30.0 by name, and qbx_ambulancejob and ox_fuel list it as a dependency.

## 2. Things that exist twice or overlap

| What | Where | Problem |
|---|---|---|
| **Trade on F6** | Unknown | Nothing in our scripts is bound to F6. Need to find what opens. |
| **Eating and drinking** | `qbx_smallresources/qbx_consumables` and `city_inventory/data/items.lua` (`client.status`) | Both define what food, drinks, alcohol, joints and coke do. qbx_consumables' `CreateUseableItem` always wins, so ours never runs for those items. Keep one. |
| **EMS shops** | Our **Medicine Cabinet** (`city_inventory/data/shops.lua`) and qbx_ambulancejob's **Armory** | Two EMS shops 3 m apart at Pillbox; the armory is free, the cabinet charges. Remove one. |
| **Clothing on/off** | qbx_radialmenu **Clothing** and illenium-appearance | Two ways to take clothes off; inventory clothing slots would make three. |
| **Give Contact Details** | qbx_radialmenu (Citizen) | Calls the old qb-phone event, which isn't installed (we use npwd): the button does nothing. Remove it or point it at npwd. |
| **Opening a trunk** | qbx_radialmenu **Vehicle Doors → Trunk** and TAB at the back of a car | Both open the lid. Harmless. |
| **Giving items as admin** | `/giveitem` and `/kit` (city_inventory), qbx_adminmenu **Give Item** | Not a duplicate: the admin menu runs our `/giveitem`. |

## 3. Money: scripts blocked by city_economy

`city_economy` owns cash and bank. qbx_core's `AddMoney` / `RemoveMoney` / `SetMoney` ask it first (`scripts/patches/qbx_core.patch`), and it only accepts the sources in `city_economy/server/config.lua` (`sources`). Everything else is refused and logged as `Refused credit/debit ... source not registered`. This is on purpose: each script comes back when it is rewritten with server-side validation (see `PROMPT_ECONOMIA_FIVEM.md`, section 11).

| Allowed now | Why |
|---|---|
| qbx_core `paycheck` | Salary, capped at $20,000/hour per character. |
| city_inventory shops and trades | Our own code, already validated on the server. |
| illenium-appearance (debit only) | Clothing store charges; it checks the result, so a refused charge means no purchase. |

Blocked until rewritten (they stop paying or charging): qbx_taxijob (also trusts the fare sent by the client), qbx_truckerjob, qbx_towjob, qbx_garbagejob, qbx_busjob, qbx_diving, qbx_pawnshop, qbx_storerobbery, qbx_truckrobbery, qbx_streetraces, qbx_properties, qbx_garages, qbx_customs, qbx_cityhall, qbx_carwash, qbx_ambulancejob, qbx_vehicleshop, qbx_vehiclesales, qbx_drugs, qbx_police, qbx_adminmenu and qbx_core's own `/givemoney` / `/setmoney`.

Renewed-Banking was removed. qbx_police (fines, impound), qbx_ambulancejob (`depositSociety`) and qbx_vehicleshop (society funds) still call `exports['Renewed-Banking']` and error when they reach that line, until job accounts exist in city_bank.
