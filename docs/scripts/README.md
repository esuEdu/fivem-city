# Scripts on the server

Every resource in `server-data/resources/`, grouped by what it's for. Third-party ones come from the Qbox txAdmin recipe and are installed by `scripts/install-resources.sh`; ours are in `[local]/`. Known problems and overlaps between them are in [issues.md](issues.md).

## Core

| Script | What it does |
|---|---|
| **qbx_core** | The framework: characters, jobs, gangs, money, admin permissions. |
| **oxmysql** | Database connection. |
| **ox_lib** | Shared toolkit: menus, notifications, progress bars, popups. |
| **ox_target** | The Alt "look at it" interaction menu. |
| **city_inventory** | Our inventory: items, weapons, shops, stashes, trunks, drops, trades. |
| **ox_inventory** (stand-in) | Lets Qbox scripts talk to our inventory. |
| **city_ui** | The shared colours and fonts for our screens. |

## Character and player

| Script | What it does |
|---|---|
| **illenium-appearance** | Character creator, clothing stores, barbers, tattoos, saved outfits. |
| **qbx_spawn** | Spawn location picker when you join. |
| **qbx_idcard** | ID card, driver's licence and weapon licence items. |
| **qbx_cityhall** | City hall: get licences and pick civilian jobs. |
| **qbx_hud** | Health, armour, hunger, thirst, stress, speedometer. |
| **qbx_medical** | Injuries, bleeding, dying and last stand. |
| **qbx_seatbelt** | Seatbelt (B) and getting thrown through the windshield. |
| **scully_emotemenu** | Emote and animation menu. |
| **qbx_radialmenu** | Radial quick menu (F1): vehicle, job and personal actions. |
| **qbx_scoreboard** | Online players list and which robberies are possible. |
| **qbx_binoculars** | Binoculars item. |
| **qbx_fireworks** | Firework items. |
| **MugShotBase64** | Takes character photos (used by ID cards and police records). |

## Money

| Script | What it does |
|---|---|
| **city_economy** | Ours: the money ledger. Owns cash and bank (qbx_core only mirrors them); scripts that pay or charge must be on its allowlist. |
| **city_bank** | Ours: bank branches (banker NPC, fingerprint, panel with accounts, cards, transfers, loans, bills, history and a staff tab for bankers), ATMs, the card machine item and the `bank_card` item. |
| **qbx_management** | Boss menu: hire, fire, promote, society money. |
| **qbx_pawnshop** | Sell stolen and valuable items for cash. |

## Vehicles

| Script | What it does |
|---|---|
| **qbx_vehicles** | Owned cars data (used by garages, keys and trunks). |
| **qbx_vehicleshop** | Car dealership (PDM) and buying cars. |
| **qbx_vehiclesales** | Used-car lot where players sell cars to each other. |
| **qbx_garages** | Parking garages, impound, house and job garages. |
| **qbx_vehiclekeys** | Car keys, locking and unlocking, lockpicking and hotwiring. |
| **ox_fuel** | Fuel, gas stations and jerry cans. |
| **qbx_customs** | Benny's / LS Customs: tuning, paint, repair. |
| **qbx_carwash** | Car wash. |
| **vehiclehandler** | More realistic damage and handling. |
| **qbx_density** | How many local (NPC) cars and pedestrians are on the streets. |
| **qbx_lapraces / qbx_streetraces** | Race tracks and street races with bets. |

## Jobs (legal)

| Script | What it does |
|---|---|
| **qbx_police** | Police: cuffing, escorting, evidence, fines, jail, locker. |
| **qbx_ambulancejob** | EMS: revive, heal, hospital beds, armory. |
| **qbx_mechanicjob** | Mechanic: repairs and parts, with the job's stash. |
| **qbx_taxijob** | Taxi with NPC fares. |
| **qbx_busjob** | Bus routes. |
| **qbx_truckerjob** | Delivery trucker. |
| **qbx_garbagejob** | Garbage collector. |
| **qbx_towjob** | Tow truck driver. |
| **qbx_newsjob** | News reporter (camera, mic). |
| **qbx_recyclejob** | Recycling centre: sort materials. |
| **qbx_scrapyard** | Scrap stolen cars for materials. |
| **qbx_vineyard** | Pick grapes and make wine. |
| **qbx_diving / qbx_divegear** | Diving for coral, and the dive gear. |
| **xt-prison** | Prison sentences, jobs inside and breakouts. |

## Crime

| Script | What it does |
|---|---|
| **qbx_storerobbery** | Rob registers and safes at 24/7 stores. |
| **qbx_houserobbery** | Break into houses and steal items. |
| **qbx_jewelery** | Vangelico jewelry store heist. |
| **qbx_bankrobbery** | Fleeca, Paleto and Pacific bank heists. |
| **qbx_truckrobbery** | Armored truck robbery. |
| **qbx_drugs** | Selling drugs to locals and corner selling. |
| **qbx_weed** | Growing weed in houses. |
| **safecracker / mhacking / ultra-voltlab** | Minigames for the heists (safes, hacking, voltage puzzle). |

## Houses

| Script | What it does |
|---|---|
| **qbx_properties** | Buy or rent houses and apartments, decorate, house stash. |

## Communication

| Script | What it does |
|---|---|
| **city_phone** | Ours, replaces npwd: the phone (used from the `phone` item): lock screen, home screen, dynamic island, control center, multitask and Settings. Each app is its own resource that registers with it. |
| **pma-voice** | Proximity voice chat. |
| **mm_radio** | Radio item for police, EMS and other channels. |
| **qbx_chat_theme** | Chat style. |

## World and admin

| Script | What it does |
|---|---|
| **qbx_adminmenu** | Admin menu: noclip, teleport, give items and money, spectate, bans. |
| **Renewed-Weathersync** | Synced weather and time. |
| **bob74_ipl** | Loads interiors (stores, offices, the bank vault). |
| **pillbox** | Pillbox hospital map. |
| **loadscreen** | The loading screen. |
| **ox_doorlock** | Locked doors (police station, banks). |
| **qbx_smallresources** | Small extras: no weapon drops from NPCs, crouch, ignore keys and more. |
| **mana_audio** | Extra sound effects. |
| **screencapture** | Lets the phone camera take screenshots. |

## Ours (`[local]/`)

| Script | What it does |
|---|---|
| **city_base** | Starter template for new scripts. |
| **city_inventory**, **city_ui**, **ox_inventory** | See Core above. |
| **city_economy**, **city_bank** | See Money above. Design and rules: `PROMPT_ECONOMIA_FIVEM.md`, `BANCO_DESIGN.md`. |
| **city_phone** | See Communication above. |
| **city_os** | The iFruit Pad tablet (item + F2): lock screen, home, notifications, Settings, and the platform other scripts add their apps to. See [city-os.md](../city-os.md). |
