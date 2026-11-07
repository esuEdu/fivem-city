# Script issues and overlaps

Scripts that need changes because the server uses `city_inventory` instead of ox_inventory, and features that exist twice. See [README.md](README.md) for what each script does.

## 1. Scripts that need fixing because of ox_inventory

### Broken or partly broken

None known.

### Fixed in `city_inventory`

- **EMS shops:** our **Medicine Cabinet** stood 3 m from the EMS **Armory** at Pillbox (now city_hospital's); it's removed from `data/shops.lua`.
- **ox_fuel:** pays with the **"money" item**, which is the player's real cash (`server/cash.lua`, `server/cashflow.lua`, `Config.CashItem`).
- **city_police** (ox_target and radial **Search**), the radial **Rob** (via `openNearbyInventory`) and the **Staff** app (**Inventory**, via `openInventory('player', id)`): player search (`server/searches.lua`).

### Already patched

- **qbx_core:** uses `city_inventory` (`scripts/patches/qbx_core.patch`).
- **qbx_medical:** tells the server when a revive is real (`qbx_medical:server:revived`), so city_hospital can keep a finished-off player down (`scripts/patches/qbx_medical.patch`).
- **qbx_radialmenu:** the dead **Give Contact Details** button is removed, and the police buttons fire city_police's events (Kidnap, Take Hostage and Revoke Drivers License are gone) (`scripts/patches/qbx_radialmenu.patch`).
- **qbx_core:** BCSO and SASP are removed from `shared/jobs.lua` and police start off duty (they clock in at a station) (`scripts/patches/qbx_core.patch`).

### Working through the `ox_inventory` stand-in (nothing to do)

illenium-appearance, mm_radio, ox_doorlock, ox_target, qbx_bankrobbery, qbx_houserobbery, qbx_jewelery, qbx_storerobbery, qbx_truckrobbery, qbx_drugs, qbx_weed, qbx_mechanicjob, qbx_taxijob, qbx_vineyard, qbx_recyclejob, qbx_scrapyard, qbx_diving, qbx_divegear, qbx_idcard, qbx_pawnshop, qbx_seatbelt, qbx_vehiclekeys, qbx_fireworks, qbx_smallresources, xt-prison.

The stand-in has to stay: about 40 scripts call `exports.ox_inventory`, ox_fuel checks for ox_inventory 2.30.0 by name, and ox_fuel lists it as a dependency. What it takes to remove it: [ox-inventory-removal.md](ox-inventory-removal.md).

## 2. Things that exist twice or overlap

| What | Where | Problem |
|---|---|---|
| **Trade on F6** | Unknown | Nothing in our scripts is bound to F6. Need to find what opens. |
| **Eating and drinking** | `qbx_smallresources/qbx_consumables` and `city_inventory/data/items.lua` (`client.status`) | Not a duplicate: no item is in both. qbx_consumables does sandwich, coffee, beer, vodka, whiskey (stress relief, drunk effect) and the drugs; `items.lua` does burger, sprunk, water and mustard. Its config also lists tosti, twerks_candy, snikkel_candy, water_bottle and kurkakola, which aren't items (harmless). Using either kind takes one item. |
| **Clothing on/off** | qbx_radialmenu **Clothing** and illenium-appearance | Two ways to take clothes off; inventory clothing slots would make three. |
| **Opening a trunk** | qbx_radialmenu **Vehicle Doors → Trunk** and TAB at the back of a car | Both open the lid. Harmless. |

## 3. Money: scripts blocked by city_economy

`city_economy` owns cash and bank. qbx_core's `AddMoney` / `RemoveMoney` / `SetMoney` ask it first (`scripts/patches/qbx_core.patch`), and it only accepts the sources in `city_economy/server/config.lua` (`sources`). Everything else is refused and logged as `Refused credit/debit ... source not registered`. This is on purpose: each script comes back when it is rewritten with server-side validation (see `PROMPT_ECONOMIA_FIVEM.md`, section 11).

| Allowed now | Why |
|---|---|
| qbx_core `paycheck` | Salary, capped at $20,000/hour per character. |
| city_inventory shops and trades | Our own code, already validated on the server. |
| illenium-appearance (debit only) | Clothing store charges; it checks the result, so a refused charge means no purchase. |
| The `money` item via `RemoveItem` (debit only, reason `inventory-cash-item`) | Lets ox_fuel charge cash. `AddItem('money')` stays blocked: any script could otherwise create cash. |

Blocked until rewritten (they stop paying or charging): qbx_taxijob (also trusts the fare sent by the client), qbx_truckerjob, qbx_towjob, qbx_garbagejob, qbx_busjob, qbx_diving, qbx_pawnshop, qbx_storerobbery, qbx_truckrobbery, qbx_streetraces, qbx_properties, qbx_garages, qbx_customs, qbx_cityhall, qbx_carwash, qbx_vehicleshop, qbx_vehiclesales and qbx_drugs.

Renewed-Banking was removed. qbx_vehicleshop (society funds) still calls `exports['Renewed-Banking']` and error when they reach that line, until job accounts exist in city_bank.

### Known limits of city_bank

- **ATM position**: ATMs are map props the server can't list, so it checks the player is within 2.5 m of the ATM position the client reports. Using an ATM still needs the physical card and its PIN, and every limit applies; only the "where" is client-reported.
- **No phone app yet**: blocking a card also works at a branch, and purchases above a card's limit are refused (the design's phone approval comes with the city_phone wallet app).
- **Job accounts**: only bosses (`isboss` grades) manage them; they can add view-only people. qbx_management still doesn't show their balance.
- **Test commands** (admin on duty): `/posdemo [amount]` opens the card machine's customer screen with a charge to yourself; `/bankwarp [id] [days]` moves a character's bank dates back (bills, installments, card cycle, scheduled transfers, pending limits) and runs the scheduler at once. Both are written to `bank_audit`.
- **Staff can't act on themselves**: approving their own loan, changing ceilings of their own cards (or cards on accounts they can use) and freezing/unfreezing those accounts is refused and flagged. Only admins lift fraud and staff freezes; bankers lift debt freezes.
- **Cash item**: `money` is the player's cash. Every move (ground, trade, stash/trunk, another player, death drop) goes through city_economy's ledger; cash on the ground lives in the `CASH_GROUND` account and is written off when a drop expires or the resource restarts, cash in storage lives in `CASH_STORED`. Trades no longer have a typed cash field: drag the money item into the offer.
