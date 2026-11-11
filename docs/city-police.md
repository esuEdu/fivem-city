# Police (`city_police`): design

Our own police for the LSPD. It replaced `qbx_police`: the field job (duty, cuffs, escort, vehicles, armory, lockers, objects, spike strips, evidence, security cameras, ankle monitors) and the **MDT**, the police app on the iFruit tablet (`city_os`). Only the `police` job exists; BCSO and SASP were removed from `qbx_core/shared/jobs.lua`.

## Who can use it

- Players with the `police` job see the **MDT** on the tablet (`access.jobs = { police = 0 }`). Everything in it needs the officer **on duty**.
- What each grade may do is `Config.Permissions` (action → lowest grade). The grades are the military police ranks in `qbx_core` `shared/jobs.lua`: 0 Recruta, 1 Soldado, 2 Cabo, 3 Terceiro Sargento, 4 Segundo Sargento, 5 Primeiro Sargento, 6 Subtenente, 7 Aspirante, 8 Segundo Tenente, 9 Primeiro Tenente, 10 Capitão, 11 Major, 12 Tenente-Coronel and 13 Coronel, the owner of the police (`isboss`, the police bank account); the Tenente-Coronel also manages. Every server callback checks it again (`server/mdt/core.lua` `mdt.register`).
- **Certifications** (`Config.Certs`: air unit, motor unit, tactical, forensics, interceptor) are given in the MDT by a Segundo Tenente or above. They unlock vehicles in the garage and forensic analysis.
- Duty starts off: officers clock in at a station (`defaultDuty = false` in jobs.lua). Hours on duty are counted per shift.

## The MDT (tablet app)

| Tab | What it does |
| --- | --- |
| **Dashboard** | Your shift (time on duty, status, callsign), open calls, units on duty, inmates in Bolingbroke now, today's arrests and fines, the command's notices. |
| **Dispatch** | Open calls: 190 calls from the phone (`city_dispatch` forwards them), automatic alerts (robberies, drug selling, car theft, officer panic button). Attach to a call (sets the GPS), detach, add a note, close. A new call shows a banner on the tablet, a blip and a sound. |
| **Map** | A live map of the city (drawn, not the game's picture) with units, calls and ankle monitors. Clicking one sets the GPS; a button opens the game's own map. |
| **Units** | Officers on duty: callsign, grade, status (available, busy, en route, on scene, break), the call each is on, how long on duty. Set your own status and callsign. The camera button watches that unit's **bodycam** live: the tablet closes, the viewer's ped hides below the unit (like the Staff app's spectate) and the game camera follows them; Backspace leaves. |
| **People** | Search by name (A to Z: "João" lists every João, first match on top), phone, citizen ID or fingerprint, or switch to **ID** for the server ID (exact: 5 shows only player 5, online only). The same Name / ID switch is in every person picker. A person's file: photo (last booking), date of birth, phone, job, licences and driving points, ankle monitor, warrants, arrests and fines, cases they're in, vehicles, registered weapons; buttons for a new case and Jail. |
| **Vehicles** | One box for a plate or an owner's name: matching citizens (with how many cars they own) and matching plates. Picking a citizen, or opening any car, shows the owner's small profile (booking photo, name, Open file) with all their cars on the left; the car on the right has its model, owner, flags (stolen / wanted, with reason), impounds and the model's picture. Flag or clear a plate. |
| **Weapons** | Search by serial: model, registered owner, where it was bought, status (registered, seized, stolen), casings matched to it. Weapons bought in a shop are registered automatically. |
| **Cases** | Title, place, evidence photos (picked from the officer's phone camera roll and copied into `city_police_case_photos`), crime tags (`Config.CaseTags`, each adds its template to the description), description (starts from a template with the date and who filed it), vehicles, officers, civilians and criminals involved; each criminal gets charges from the penal code with the months and fine added up. From a saved case: **Fine** a criminal (a bank bill; someone not in the city gets it through `city_bank:IssueBill`, due in `offlineFineDays`) or **Jail** them (opens the Prison tab with the case attached). A case being written is a draft kept in the page's storage per character: closing the tablet and opening it again goes back to it. Officers write and edit their own; sergeants and up edit any. |
| **Warrants** | (Off in V1: `Config.Features.warrants`.) Arrest warrants with reason, charges and expiry. Terceiro Sargento and up issue or cancel them; any officer marks one served (an arrest of that person serves it automatically). `exports.city_police:IssueWarrant` still works. |
| **BOLOs** | "Be on the lookout": a person or a vehicle (with plate) to watch for, no warrant or known citizen needed. Any officer creates one (title, description, hours valid, `boloHours` default) and every unit on duty gets a banner; any officer closes it. The Dashboard counts the active ones. |
| **Prison** | Who is in Bolingbroke now (from `exports.city_prison:Inmates`), and booking an arrest: the suspect (Name / ID search, must be in the city), a case they are a criminal in (its charges fill in), charges with × and + Add, the reason, and a reduction (percent off for a first arrest or a lawyer, or a set time; `records.reduce`). The arrest takes the booking photo and fingerprint, bills the fine and sends them to city_prison. The prison computer still changes and ends sentences. |
| **Penal code** | Look-only: every crime as a card colored by category (infraction, misdemeanor, felony) with months, fine and points, and a search. The same cards are the charge picker in Cases and Prison. |
| **Impounds** | Impounded vehicles (reason, fee, hold time, officer) and the evidence locker contents. Impound the car in front of you; release (Terceiro Sargento+) or the owner pays at the station desk after the hold time. |
| **Licences** | Driver, weapon and explosives licences of a person, driving points in the last 30 days. Grant or revoke (weapon and explosives: Terceiro Sargento+; explosives lets city_mining sell that person the dynamite card). The driver licence is suspended by itself at `Config.Licences.maxPoints`. |
| **Evidence** | Evidence bags in your inventory: analyze them at the lab (forensics certification) to turn a casing into a weapon serial, blood into a DNA match and a fingerprint into a person. Results are saved and can go into a report. |
| **Cameras** | The security cameras of shops, banks and the jeweler. Viewing one puts the tablet away; arrows change camera, Backspace leaves. Cameras a robbery cut show as offline. |
| **Certifications** | Each officer's certifications; Segundo Tenente and up give or take them. |
| **Management** | Every officer sees the roster: rank, hours this week and in total, on duty / online / offline. The Coronel and Tenente-Coronel send a job offer by server id (the player accepts or declines on screen), change ranks (only below their own) and fire; notices for the Dashboard. |

## The field job

- **Stations** (`Config.Stations`, Mission Row and Paleto Bay): clock in/out, armory (a `city_inventory` shop, items by grade), personal locker, evidence locker (stash), trash, garage and helipad, impound desk, forensics lab. All with `ox_target`.
- **Doors** (`doors` in `server/config.lua`, `server/doors.lua`): the Mission Row cells, armory, locker rooms, offices, back entrance and garage gate are ox_doorlock doors that only the police job opens and locks (E near the door). city_police creates each one by name when it is missing, so a door staff changed with `/doorlock` keeps the change.
- **Wardrobe** (`wardrobe` in `Config.Stations`, `server/wardrobe.lua`): a panel with the uniforms for the character's body (`Config.Uniforms` plus the ones made in game). Putting one on keeps the officer's own clothes in `city_police_wardrobe` (once, so switching uniforms doesn't lose them); "Change back" or "Go off duty and change back" puts them back, even after logging out. Clothes are read and set on the ped with the game natives, never saved as the skin. The command (`Config.Permissions.uniforms`, Tenente-Coronel and up) makes a uniform in illenium-appearance's clothing editor, names it and can delete it (max `Config.MaxUniforms`); a uniform only ever touches clothes (components 1 and 3 to 11 and the hat), never the face, hair, glasses, ears, watch or bracelets, and a uniform without a hat takes the hat off. `server/outfit.lua` keeps that list, leaves bad pieces out and logs them (tested).
- **Vehicles**: one at a time per officer, from the garage they stand at, models by grade and certification, plate `LSPD####`, keys given.
- **Police actions** (ALT on a player or a vehicle shows one ox_target item that opens a round menu, `client/radial.lua` on the screen page): on a player, open their file in the MDT (the tablet opens on People through `exports.city_os:OpenApp`), cuff, soft cuff, escort, put in a vehicle, search, fine (the MDT opens a new case with this officer and the person as a criminal, or adds them to the case being written), check status; on a vehicle, open it in the MDT, take someone out, impound. Putting in and taking out ask for the seat (2 front passenger, 3 rear left, 4 rear right, more for vans; the driver's seat is only offered to take out); the server checks the seat is free.
- **On players** (the actions above, and qbx_radialmenu's police buttons): cuff / uncuff (needs `handcuffs`), soft cuff (can walk), escort, put in / take out of a vehicle, search (`city_inventory` player search; a suspect who isn't cuffed, down or hands up gets an Allow/Refuse prompt first, `search` in `server/config.lua`, and `server/search.lua` blocks the inventory opening without it through city_inventory's `openInventory` hook), check status (gunpowder, alcohol, smells), scan fingerprint, ankle monitor on/off. Every action is checked on the server (job on duty, distance, the target's state).
- **Cuffed players** can't run, shoot, drive or open the inventory/phone/tablet; the `ishandcuffed` metadata is set on the server. A soft cuff can be broken with a skill check.
- **Objects** (radial menu): cones, barriers, road signs, lights, tent; spike strips burst the tyres of cars that drive over them (max `Config.MaxSpikes` per officer). Pick them up again from the radial menu.
- **Evidence**: shooting drops casings (with the weapon's serial), wounds drop blood, robberies leave fingerprints (no gloves). Officers on duty see them when aiming a flashlight, and pick them up with an `empty_evidence_bag`. Evidence on the ground disappears after `Config.Evidence.minutes`.
- **Ankle monitor**: the person's position shows on the MDT map while it's on.
- **Arrest**: only with the suspect cuffed or down and the officer at a booking place (`bookingPlaces` in `server/config.lua`: Mission Row, Paleto Bay, Bolingbroke; an empty list allows anywhere). Fines have no such limit. The suspect sees an arrest screen with the months and the crimes, the arrest goes in their record, and `city_prison` takes them straight to Bolingbroke ([city-prison.md](city-prison.md)).
- **Panic button** (`/p`, `p` in F8, a key the officer binds in the game's key bindings, or radial "Emergency"; `Config.PanicCommand`): a high-priority call with the officer's position.
- **Call popups**: every new call and radio code shows a card at the top left for `Config.Dispatch.popup.seconds` (10); F10 takes the newest (attaches to the call and sets the GPS), F11 dismisses it; at most `popup.max` (4) at once, the oldest makes room.
- **Officers on the map**: every officer on duty sees the others as blue blips with their callsign (an arrow on foot, a car in a vehicle), from `server/unitblips.lua` every `Config.UnitBlips.seconds`.
- **Badge** (`police_badge`, free at the armory): using it shows a card with the department, name, rank, callsign and badge number to the officer and everyone within `Config.Badge.range`, while the officer holds the badge up (`server/badge.lua`). Only the police job can show one.
- **Radio**: mm_radio is the device (the `radio` item, free at the armory; channels 1 to 10 are police and EMS only), talked through with Caps Lock (`voice_defaultRadio` in `server.cfg`; Left Alt is ox_target's). The list of who is in the channel is `city_radio`, which shows callsigns from `exports.city_police:Callsign`.
- **Patrol car menu** (F6 in an emergency-class car, on duty): radio codes (`Config.RadioCodes`, `server/radio.lua`) that pop up for every unit (Code 99 opens a priority call) and may set the sender's status, and the radar buttons. The mouse is free and the car can still be driven.
- **Tackle** (G while sprinting, `Config.Keys`): the player just ahead falls for `Config.Tackle.suspectMs` and the officer briefly too. Server: on duty, in reach, neither in a car, `tackleCooldown` seconds between tackles.
- **Zip ties and head bag** (`zipties`, `head_bag`; YouTool sells both, the armory has zip ties): anyone uses them on the closest player who has their hands up, is cuffed or is down. Zip ties are cuffs (`ishandcuffed`) marked with the `zipTied` state bag; anyone with a blade (`zipCutters`) cuts them with ox_target, and police uncuffing also frees them. The head bag is the `headBag` state bag: the wearer's screen goes black and a bag sits on their head; anyone close takes it off (and gets the item back), or it falls off after `headBagMinutes`.
- **Crowbar** (`crowbar`, from the armory): ox_target "Force open" on a locked car, police on duty; the server times the 8 seconds itself (start and finish callbacks) and unlocks through `qbx_vehiclekeys:SetLockState`, logged.
- **Patrol car radar** (F7 on/off, F9 freeze, or the F6 menu, in an emergency-class car): a dash unit at the bottom with your own speed and the speed and plate of the car ahead and behind, read on the client only.
- **Megaphone** (hold Y in an emergency-class car): the voice range is `Config.Megaphone.range` through pma-voice's proximity override.

## Calls (dispatch)

`city_police` owns the police calls (`server/dispatch.lua`), in memory, each lasting `Config.Dispatch.minutes`:

- 190 calls: `city_dispatch` calls `exports.city_police:PhoneCall(src, kind, text, caller)`; when the first unit attaches, city_police fires `city_police:server:callAccepted` and the caller hears the police are on the way.
- Scripts: `exports.city_police:Alert({ title, text, coords, code, priority })`, server only.
- Shots fired (`server/alerts.lua`, from the shot reports that also drop casings): anyone but police on duty shooting inside `shots.areas` makes a 10-71 call; with a suppressor attached only `suppressedChance` (20%) of reported shots do. After a call the same shooter makes no new one for `shots.cooldown` seconds (20).
- Officer down: an officer on duty whose `qbx_medical:deathState` stops being alive makes a high-priority 10-99 call.
- Old qbx_police events still work, for the vendored robbery scripts: `police:server:policeAlert`, `evidence:server:CreateFingerDrop`, `evidence:server:CreateBloodDrop`, and on the client `evidence:client:SetStatus` and `police:client:SendPoliceEmergencyAlert` (`server/compat.lua`, `client/compat.lua`). `police:SetCopCount` is still sent to everyone when the number on duty changes.

## Data

Tables, created on start:

| Table | Holds |
| --- | --- |
| `city_police_officers` | citizenid, name, callsign, certifications, minutes on duty, last duty |
| `city_police_shifts` | one row per shift (start, end), for hours per week |
| `city_police_records` | arrests, fines and citations: charges, months, fine, points, officer, booking photo and fingerprint |
| `city_police_reports` | cases: tags, people with roles and charges, plates, photo ids |
| `city_police_case_photos` | evidence photos copied from officers' phones (unsaved ones deleted after a day) |
| `city_police_uniforms` | uniforms the command made in game: label, body, components, props |
| `city_police_wardrobe` | an officer's own clothes while they wear a uniform |
| `city_police_warrants` | warrants: charges, expiry, status |
| `city_police_bolos` | BOLOs: kind, title, description, plate, expiry, status |
| `city_police_plates` | flagged plates (stolen / wanted) |
| `city_police_weapons` | registered weapons by serial |
| `city_police_impounds` | impounds: plate, reason, fee, hold until, released |
| `city_police_evidence` | analyzed evidence results |
| `city_police_notices` | the command's notices |

Licences stay in qbx_core's `metadata.licences`; driving points are summed from records. Vehicles are qbx's `player_vehicles` (an impounded car has `state = 2` until released, then `0`, so it's in the depot).

## Money

Fines and impound fees are **bank bills** (`exports.city_bank:CreateBill`, kind `fine`, split between the treasury and the police account as `city_bank` says). city_police never adds or removes money itself. Cash found on a suspect is taken through the search screen like any item.

## Not in v1

K9, recorded bodycam footage, the helicopter camera, court and lawyers, evidence photos.
