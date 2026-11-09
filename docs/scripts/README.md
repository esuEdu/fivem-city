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
| **qbx_hud** | Health, armour, hunger, thirst, stress, speedometer. |
| **qbx_medical** | Injuries, bleeding, dying and last stand. |
| **qbx_seatbelt** | Seatbelt (B) and getting thrown through the windshield. |
| **scully_emotemenu** | Emote and animation menu. |
| **qbx_radialmenu** | Radial quick menu (F1): vehicle, job and personal actions. |
| **qbx_scoreboard** | Online players list. |
| **MugShotBase64** | Takes character photos (used by ID cards and police records). |

## Money

| Script | What it does |
|---|---|
| **city_economy** | Ours: the money ledger. Owns cash and bank (qbx_core only mirrors them); scripts that pay or charge must be on its allowlist. |
| **city_bank** | Ours: bank branches (banker NPC, fingerprint, panel with accounts, cards, transfers, loans, bills, history and a staff tab for bankers), ATMs, the card machine item and the `bank_card` item. |
| **qbx_management** | Boss menu: hire, fire, promote, society money. |

## Vehicles

| Script | What it does |
|---|---|
| **qbx_vehicles** | Owned cars data (used by garages, keys and trunks). |
| **city_dealership** | Ours, replaces qbx_vehicleshop: Premium Deluxe Motorsport. A computer in the showroom opens the catalogue (every civilian car by category, search, sort, photo, stats), test drives, buying in full (cash or bank) or financed (down payment, then one bank bill per installment; the car is taken back when bills go overdue). Bought cars wait at the PDM garage outside. |
| **city_garages** | Ours, replaces qbx_garages: unified garages (park in one, take out in any other of the same kind: cars, air, boats), gang and house garages, impound lots with a fee, a list with search and favorites, and the car's picture and condition before taking it out. |
| **qbx_vehiclekeys** | Car keys, locking and unlocking, lockpicking and hotwiring. |
| **ox_fuel** | Fuel, gas stations and jerry cans. |
| **vehiclehandler** | More realistic damage and handling. |
| **qbx_density** | How many local (NPC) cars and pedestrians are on the streets. |

## Jobs (legal)

| Script | What it does |
|---|---|
| **city_police** | Ours, replaces qbx_police: the LSPD job (duty, armory, lockers, garage and helipad, cuff/escort/search, objects and spike strips, evidence, security cameras, ankle monitors, speed cameras, impounds) and the **MDT** tablet app (dispatch, live map, units, people, vehicles, weapons, reports, warrants, charges, impounds, licences, evidence, cameras, certifications, management). See [city-police.md](../city-police.md). |
| **city_hospital** | Ours, replaces qbx_ambulancejob: EMS job (duty, garage, armory, locker, Pillbox elevator, calls, examine/revive/treat/bill), downed screen, `/finalizado`, hospital respawn, beds, NPC reception and the NPC ambulance. |
| **city_mechanic** | Ours, replaces qbx_mechanicjob and qbx_customs: the mechanic job at LS Customs (Burton): clock in, the shop storage, work vehicles (flatbed, tow truck) and the **tuning bay**: a mechanic on duty drives the car in and presses E to open the tuning menu (performance, body parts, paint, wheels, lights, extras, full repair), previewed live on the car with an orbiting camera; the parts are paid from the mechanic job's bank account. Repair kits and the cleaning kit work anywhere (mechanics on duty fix more). |
| **city_militech** | Ours: the **Militech Tuning** item (given by staff for now, not used up). From the driver seat of a stopped car it opens a Forza-style tuner: tires, gearing, alignment, anti-roll bars, springs, damping, aero, brakes and engine sliders that change the car's handling within tight limits, with Forza-like stat bars and a PI class (D to X). Setups are checked on the server and saved on owned cars. |
| **city_militech_staff** | Ours: the **Staff Militech** item, for staff only (item + `group.admin`). The same tuner, but every handling field is an absolute value you can type in or slide: engine, gearing, drivetrain (FWD/RWD/AWD), tires, alignment, springs and suspension travel, damping, anti-roll, aero, brakes, weight and centre of mass, inertia and damage multipliers. It replaces the car's Militech setup while it is on. It is saved on owned cars and every change goes to the staff log. |
| **city_dispatch** | Ours: calls to the city services from the phone (type, text, anonymous, location): mechanics on duty get a phone notification, a blip and `/calls`; 190 goes to city_police's calls (the MDT) and 192 to city_hospital's EMS calls. The caller only hears that someone is on the way. |
| **city_prison** | Ours, replaces xt-prison: Bolingbroke sentences (an arrest in the MDT sends the suspect straight in; one month = one minute played), belongings in a locker (illegal items to the police evidence locker), jobs that cut the time, contraband crafting (shank, gate jammer, burner phone), escapes with a gate hack, alarm and an MDT warrant, and the prison computer for the police. See [city-prison.md](../city-prison.md). |
| **city_fishing** | Ours: fishing, the first legal job, open to anyone with a fishing licence. Rods, bait and tackle from the fishing shop, a catch minigame, 30 fishing levels with a skill tree, the fish market with prices that drop as fish are sold, crab pots anyone can pull, boat rental at the marina, very rare legendary fish, frenzies and tournaments, and the **Fishing** tablet app. See [city-fishing.md](../city-fishing.md). |
| **city_mining** | Ours: mining, the second legal job, open to anyone with a mining licence. Veins in four tiers on hand-placed points across the map (Davis Quartz to Mount Chiliad) that run out and come back elsewhere, a strike minigame, the public smelter (stamped ingots) and home furnaces (unstamped), geodes, gem cutting and jewellery at Vangelico, panning in the rivers, dynamite (police-granted licence), super rocks, cave-ins, a crime buyer, 30 levels with a skill tree and the **Mining** tablet app. See [city-mining.md](../city-mining.md). |

## Crime

| Script | What it does |
|---|---|
| **safecracker / mhacking / ultra-voltlab** | Minigames for the heists (safes, hacking, voltage puzzle). |

## Houses

| Script | What it does |
|---|---|
| **qbx_properties** | Buy or rent houses and apartments, decorate, house stash. |

## Communication

| Script | What it does |
|---|---|
| **city_phone** | Ours, replaces npwd: the phone (used from the `phone` item): lock screen, home screen, dynamic island, control center, multitask and Settings. Each app is its own resource that registers with it. |
| **city_phone_camera** | Ours: the Camera app: back camera with zoom, selfie, filters (game timecycles), HUD hidden; the server takes the picture with screencapture. |
| **city_phone_photos** | Ours: the Photos app: up to 300 photos per character in the database, favorites, delete, photo wallpaper. |
| **city_phone_wallet** | Ours: the Wallet app: city_bank on the phone (balance and statement, Pix by phone or account number, block cards, contactless, card limits) and approving card purchases over the limit. |
| **city_phone_notes**, **city_phone_clock**, **city_phone_calendar**, **city_phone_weather** | Ours: Notes (pinned, search), Clock (world clock, real-time alarms that ring with the phone closed, stopwatch, timer), Calendar (month view), Weather (now + forecast from Renewed-Weathersync, patched to export GetForecast). |
| **city_phone_messages** | Ours: the Messages app: chats and groups (up to 10), delivered/read, reactions, fixed and live (15 min) location, and the route set on your map. |
| **city_phone_gps** | Ours: the Maps app: opens the game map (set a route, your position moves) and shows the route you have set, with its distance and a button to clear it. |
| **city_phone_market** | Ours: the Market app: classified ads (category, price, description, a photo from Photos, number shown or not) for 7 days at $100 from the bank, up to 5 per character, search, favorites, "Contact" opens Messages; mods remove ads. |
| **city_phone_social** | Ours: InstaPic, the photo social app: one account per character (@username, name, bio, profile photo), posts from your Photos with captions, likes, comments, follows and a feed, explore, 24-hour stories, notifications, and mods remove posts and comments. |
| **city_phone_dating** | Ours: Matchy, the dating app: a profile with up to 3 photos from Photos, name, bio, age from the character and who you want to see; cards to like or pass, matches with a notification, a private chat that never shows numbers, unmatch. |
| **city_phone_darkchat** | Ours: DarkChat, anonymous chat rooms shown only on phones carrying the `darkchat_usb` item: rooms found only by exact name (optional password), a chosen alias, messages deleted after 24 h. |
| **city_phone_news** | Ours: Weazel News: articles (headline, story, category) written by reporters on duty, breaking news that notifies every phone, likes and comments; the author, the paper's boss and mods delete. |
| **city_phone_music** | Ours: the Music app: search YouTube by title (server key `youtube_api_key`) or paste a YouTube / https audio link, library and playlists, shuffle and repeat, mini player and the dynamic island; only the phone's owner hears it. |
| **city_phone_calls** | Ours: the Phone app: calls through pma-voice (up to 4 people, mute, hidden number), contacts, favorites, recents, blocked numbers and sharing your contact with people nearby, and the city services (190 police, 192 EMS, mechanic) as fixed contacts that send a written call. |
| **pma-voice** | Proximity voice chat. |
| **mm_radio** | Radio item for police, EMS and other channels. |
| **qbx_chat_theme** | Chat style. |

## World and admin

| Script | What it does |
|---|---|
| **Renewed-Weathersync** | Synced weather and time. |
| **bob74_ipl** | Loads interiors (stores, offices, the bank vault). |
| **pillbox** | Pillbox hospital map. |
| **gemera** | Koenigsegg Gemera add-on car (model `gemera`, spawned from the staff tablet; not sold at the dealership). Our own: converted from Forza with its own meta files (2-seat layout, handling, mod kit with "No Wing", Midnight Violet livery). |
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
| **city_hospital**, **city_police** | See Jobs above. |
| **city_garages**, **city_dealership** | See Vehicles above. |
| **city_phone** | See Communication above. |
| **city_os** | The iFruit Pad tablet (item + F2): lock screen, home, notifications, Settings, and the platform other scripts add their apps to. See [city-os.md](../city-os.md). |
| **city_staff** | The **Staff** tablet app (replaced qbx_adminmenu): players and actions, `/report` reports, warnings, bans, staff log, noclip and other staff tools, vehicles. See [city-staff.md](../city-staff.md). |
