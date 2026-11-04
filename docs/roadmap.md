# v1 roadmap: the car city

A semi-serious RP city whose first version is built around cars: racing, drifting and drag, as our own festival-style system (inspired by open-world racing games, with its own name, menus and art). Status: testing with friends, no launch date.

Tick items off as they're done. Order: Phase 0 → Phase 1a (City OS) → Phase 1 → then 2–5 in any order.

## Phase 0: Clean base

- [ ] Fix fuel payment (ox_fuel pays with the `money` item; map it to qbx cash in `city_inventory`)
- [ ] Player search: police **Search** / citizen **Rob** (`openNearbyInventory`) and the admin menu's **Open inventory**
- [ ] Remove duplicates from [scripts/issues.md](scripts/issues.md): food/drink effects defined twice, the second EMS shop, the dead **Give Contact Details** button
- [ ] Find what the **F6 trade** is
- [x] Commit the project skills (`.claude/skills/`), `scripts/check.sh`, `scripts/make-patch.sh` and `tests/`

## Phase 1a: City OS (`city_os`): the central control system

Everything players control (races, garage, tuning, leaderboards, events, profile) is an **app** in one system, with three screens that share the same apps and the inventory's look:

| Screen | Opens | Feels like |
|---|---|---|
| **Tablet** | Use the tablet item on foot (hold-tablet animation) | RP: a device in your hands |
| **In-car dashboard** | In a vehicle (automatically or with a key) | The car's infotainment: car apps first |
| **Hub menu** | Full screen at the festival hub, and from the OS's Festival app | A racing game's festival menu: big event cards, rank, leaderboards |

- [ ] Design pass: home screen, app layout, which apps show on which screen, keys
- [ ] Platform: screens, home screen, notifications, and an API for other resources to register apps (`exports.city_os:RegisterApp`)
- [ ] Tablet item and animation (hold-tablet anim, `prop_cs_tablet`); in-car dashboard; hub menu
- [ ] Tablet look: **iPad-style**: thin rounded bezel, app grid on a wallpaper, a dock, status bar (time, battery), the swipe-up home bar, smooth open/close animations. Branded with GTA's own **iFruit** (the in-game Apple parody) or our City OS name; no Apple names or logos
- [ ] First apps:
  - [ ] **Profile**: character, rank, money
  - [ ] **Jobs (legal)**: one app per job (police, EMS, mechanic, taxi, …), shown only to players with that job: clock in/out, tasks, job tools; the boss also gets hire, fire, grades and the society account (today's qbx_management boss menu)
  - [ ] **Jobs (illegal)**: drugs, robberies, chop shop, …; hidden from the home screen until unlocked (an item, a contact or reputation), so a police search of the tablet doesn't show it; contacts, jobs on offer, reputation
  - [ ] **Staff**: only for staff (`group.support`/`mod`/`admin`, on admin duty): player list, spectate, teleport to/bring, heal/revive, freeze, open a player's inventory, warn/kick/ban, and reports from players
- [ ] Every app action is checked again on the server (job, grade, illegal unlock, staff group + `IsOptin`): hiding an app is only UX

**What goes where:**

| City OS (tablet / car / hub) | Phone (npwd) |
|---|---|
| Jobs, legal and illegal (clock in, tasks, job tools, boss tools) | Calls and messages |
| Staff tools (admins only) | |
| Races and events: join, **create races**, leaderboards | Social apps: dating ("Tinder"-style), photos ("Instagram"-style), Twitter |
| Garage, tuning, car rating | Contacts, camera, email |
| Profile, rank, money, city events | Everything about talking to other people |

Rule of thumb: doing things in the city (work, cars, racing, creating) → City OS; talking to people → phone.

The phone will be **our own** (`city_phone`, built from zero to replace npwd; see Phase 3). Build City OS so its app system and UI pieces can be reused by the phone: the phone is then another screen of the same platform, with its own (social) apps.

## Phase 1: Racing core (`city_racing`)

Its screens (events, results, leaderboards, race creator) are City OS apps.

Our own racing system, replacing `qbx_lapraces` and `qbx_streetraces`. Needs a design pass first (how each event type feels, rewards, rules).

- [ ] Event types: **circuit** and **sprint**
- [ ] **Drift** events: points from angle × speed × combo, with a chain multiplier
- [ ] **Drag** events: countdown, reaction time, elapsed-time slip
- [ ] Open-world challenges: **speed traps**, **drift zones**, **jump distance**, each with a leaderboard
- [ ] Car rating: a performance score and classes worked out from handling, so races are fair by class
- [ ] In-game **race creator**: place checkpoints, save tracks, laps and class rules
- [ ] Racing HUD: position, lap, timer, countdown; results screen
- [ ] Leaderboards and rewards: money, and a racer rank/XP to level up
- [ ] A **festival hub** on the map (our own name) to join events

## Phase 2: Car life

- [ ] Dealership prices and classes; a ladder from starter cars to supercars
- [ ] Tuning (qbx_customs) feeds into the car rating
- [ ] Car meets
- [ ] Street races are illegal (police alerts); hub races are legal

## Phase 3: One look for the city

Restyle in the inventory's style (`city_ui` theme):

- [ ] HUD and speedometer
- [ ] Notifications and menus
- [ ] Loading screen
- [ ] **Our own phone** (`city_phone`, from zero, replacing npwd), on the City OS platform:
  - [ ] Calls (with pma-voice) and messages, contacts, camera (screencapture), email
  - [ ] Social apps: dating ("Tinder"-style), photos ("Instagram"-style), Twitter-style
  - [ ] Replace what uses npwd today: the `phone` item's on/off (`city_inventory/data/items.lua`), qbx_vehicleshop, the qbx_npwd bridge, and the npwd garage and mail apps (their features move to City OS / the new phone)
  - [ ] Remove npwd, qbx_npwd and `[npwd-apps]` from `install-resources.sh` and `server.cfg`

## Phase 4: Maps and models

3D assets come from map and car creators (free or paid releases); we install them, wire them into the server and turn circuits into tracks in our race system.

- [ ] Choose and install race circuit maps
- [ ] MLOs (e.g. a redone Legion Square, hub location)
- [ ] Add-on car models (added to the dealership and car classes)

## Later: character models

Custom character models are add-on peds (illenium-appearance can list them). The normal GTA character (freemode) is what supports clothes, hair and faces, and fully custom models usually lose that, so most servers keep freemode and add clothing packs. Decide this before changing base models.

## Phase 5: The rest of the city (lighter for v1)

- [ ] Starting money, salaries and shop prices
- [ ] Police and EMS pass
- [ ] Balance robberies and drugs; police chases tie in with street racing
