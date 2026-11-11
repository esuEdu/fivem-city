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
- **qbx_core** and **city_dealership:** the `gemera` add-on car is in qbx_core's vehicle list and on the dealership's `Config.Blocklist`, so it can be spawned but isn't sold (`scripts/patches/qbx_core.patch`).
- **ox_doorlock:** its panel is replaced by our own page in the city_ui look (`web/city`, same NUI messages and callbacks, plus a group picker fed by the `ox_doorlock:getGroups` callback), the `/doorlock` command is removed (staff open the panel from the Staff app's My tools), and the lock icon by a door is green when unlocked, red when locked and pops when it changes (`scripts/patches/ox_doorlock.patch`).
- **qbx_scoreboard:** lists no robberies, since the robbery scripts were removed (`scripts/patches/qbx_scoreboard.patch`).
- **qbx_radialmenu:** the dead **Give Contact Details** button is removed, the police buttons fire city_police's events (Kidnap, Take Hostage and Revoke Drivers License are gone), and the mechanic, taxi and tow job buttons and Corner Selling are gone with their scripts (`scripts/patches/qbx_radialmenu.patch`).
- **qbx_core:** `shared/jobs.lua` keeps only `unemployed`, `police` (which starts off duty; officers clock in at a station), `ambulance` and `mechanic` (city_mechanic); every other upstream job is removed, and a character saved with a removed job loads as unemployed (`scripts/patches/qbx_core.patch`).

### Working through the `ox_inventory` stand-in (nothing to do)

illenium-appearance, mm_radio, ox_doorlock, ox_target, qbx_idcard, qbx_seatbelt, qbx_vehiclekeys, qbx_smallresources.

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
| city_garages (impound lot fee `garage-depot`, refund `garage-refund`) | Our own code; the fee is worked out on the server. |
| city_dealership (debit `dealership-buy`, `dealership-payoff`; refund `dealership-refund`) | Our own code; prices come from qbx_core's vehicle list on the server. Installments are city_bank bills. |
| city_mechanic (through city_bank `ChargeJob`, reason `bank-job-purchase`) | Parts fitted in the tuning bay are paid from the mechanic job's account, never a player's; the server prices the cart from its own config and only resources in city_bank `settings.jobPurchases` may charge a job. |
| city_staff Give money (credit, `staff-grant`, $1,000,000 per character per hour) | Admins only, with a reason written to the staff log. |
| illenium-appearance (debit only) | Clothing store charges; it checks the result, so a refused charge means no purchase. |
| The `money` item via `RemoveItem` (debit only, reason `inventory-cash-item`) | Lets ox_fuel charge cash. `AddItem('money')` stays blocked: any script could otherwise create cash. |

Blocked until rewritten (they stop paying or charging): qbx_properties. qbx_vehicleshop was replaced by city_dealership and qbx_customs by city_mechanic.

Renewed-Banking was removed.

### Known limits of city_bank

- **ATM position**: ATMs are map props the server can't list, so it checks the player is within 2.5 m of the ATM position the client reports. Using an ATM still needs the physical card and its PIN, and every limit applies; only the "where" is client-reported.
- **Job accounts**: only bosses (`isboss` grades) manage them; they can add view-only people. No in-game screen shows their balance (qbx_management was removed; gang accounts show in the city_orgs apps).
- **Test commands** (admin on duty): `/posdemo [amount]` opens the card machine's customer screen with a charge to yourself; `/bankwarp [id] [days]` moves a character's bank dates back (bills, installments, card cycle, scheduled transfers, pending limits) and runs the scheduler at once. Both are written to `bank_audit`.
- **Staff can't act on themselves**: approving their own loan, changing ceilings of their own cards (or cards on accounts they can use) and freezing/unfreezing those accounts is refused and flagged. Only admins lift fraud and staff freezes; bankers lift debt freezes.
- **Cash item**: `money` is the player's cash. Every move (ground, trade, stash/trunk, another player, death drop) goes through city_economy's ledger; cash on the ground lives in the `CASH_GROUND` account and is written off when a drop expires or the resource restarts, cash in storage lives in `CASH_STORED`. Trades no longer have a typed cash field: drag the money item into the offer.

## 4. Jobs we don't have yet

Only `unemployed`, `police`, `ambulance` and `mechanic` (city_mechanic) exist; the upstream jobs (taxi, bus, trucker, tow, garbage, reporter, realestate, cardealer, judge, lawyer, vineyard, hotdog) and their scripts (qbx_taxijob, qbx_busjob, qbx_truckerjob, qbx_towjob, qbx_garbagejob, qbx_recyclejob, qbx_vineyard, qbx_newsjob, qbx_mechanicjob) were removed. Until we make our own:

- **city_phone_news**: nobody can write articles (`Config.Jobs` is `reporter`); reading still works.
- **qbx_properties**: `/createproperty` needs the `realestate` job, so new properties can't be made; existing ones still work.
- **illenium-appearance**: its job outfits for removed jobs are never shown.
- Items those scripts used (news camera, mechanic parts, grapes, recycling materials, …) stay in `city_inventory/data/items.lua`, so players keep what they have.
- Characters saved with a removed job load as unemployed; their `player_groups` rows for those jobs are skipped with a warning by qbx_core and left in the database.

## 5. Features removed with their scripts

These qbx scripts were removed and have no replacement yet: qbx_bankrobbery, qbx_jewelery, qbx_storerobbery (city_robbery now robs 24/7 registers and ATMs), qbx_truckrobbery, qbx_houserobbery, qbx_drugs, qbx_weed, qbx_pawnshop, qbx_scrapyard, qbx_lapraces, qbx_streetraces, qbx_diving, qbx_divegear, qbx_fireworks, qbx_binoculars, qbx_carwash, qbx_vehiclesales and qbx_cityhall (qbx_vehicleshop was replaced by city_dealership).

- **No selling cars to other players** (qbx_vehiclesales); new cars are bought at city_dealership.
- **No car wash.**
- **No city hall**: licences and replacement ID cards can't be bought. New characters still get their ID and driver's licence from qbx_core's starting items (qbx_idcard).
- **No robberies, drugs, weed, pawn shop, scrapyard, diving or races.** Their items stay in `city_inventory/data/items.lua`, so players keep what they have, but most no longer do anything.
- Their tables (`vehicle_financing`, `occasion_vehicles`, `weed_plants`, `lapraces`, `dealers`) stay in the database; `scripts/import-sql.sh` no longer creates them.
- city_police still handles qbx_police's camera events (`police:client:SetCamera`), and city_phone the old `qb-phone` mail and alert events, for scripts added later.
