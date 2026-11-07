# Police (`city_police`): design

Our own police for the LSPD. It replaced `qbx_police`: the field job (duty, cuffs, escort, vehicles, armory, lockers, objects, spike strips, evidence, security cameras, ankle monitors, radars) and the **MDT**, the police app on the iFruit tablet (`city_os`). Only the `police` job exists; BCSO and SASP were removed from `qbx_core/shared/jobs.lua`.

## Who can use it

- Players with the `police` job see the **MDT** on the tablet (`access.jobs = { police = 0 }`). Everything in it needs the officer **on duty**.
- What each grade may do is `Config.Permissions` (action → lowest grade: Recruit 0, Officer 1, Sergeant 2, Lieutenant 3, Chief 4). Every server callback checks it again (`server/mdt/core.lua` `mdt.register`).
- **Certifications** (`Config.Certs`: air unit, motor unit, tactical, forensics, interceptor) are given in the MDT by a lieutenant or above. They unlock vehicles in the garage and forensic analysis.
- Duty starts off: officers clock in at a station (`defaultDuty = false` in jobs.lua). Hours on duty are counted per shift.

## The MDT (tablet app)

| Tab | What it does |
| --- | --- |
| **Dashboard** | Your shift (time on duty, status, callsign), open calls, units on duty, active warrants, today's arrests and fines, the chief's notices. |
| **Dispatch** | Open calls: 190 calls from the phone (`city_dispatch` forwards them), automatic alerts (robberies, drug selling, car theft, flagged plates on radars, officer panic button). Attach to a call (sets the GPS), detach, add a note, close. A new call shows a banner on the tablet, a blip and a sound. |
| **Map** | A live map of the city (drawn, not the game's picture) with units, calls and ankle monitors. Clicking one sets the GPS; a button opens the game's own map. |
| **Units** | Officers on duty: callsign, grade, status (available, busy, en route, on scene, break), the call each is on, how long on duty. Set your own status and callsign. |
| **People** | Search by name, phone, citizen ID or fingerprint. A person's file: photo (last booking), date of birth, phone, job, licences and driving points, ankle monitor, warrants, arrests and fines, reports they're in, vehicles, registered weapons. |
| **Vehicles** | Search by plate or owner: model, owner, flags (stolen / wanted, with reason), impounds. Flag or clear a plate. |
| **Weapons** | Search by serial: model, registered owner, where it was bought, status (registered, seized, stolen), casings matched to it. Weapons bought in a shop are registered automatically. |
| **Reports** | Incident reports: title, type, place, text, people involved (with roles), vehicles, evidence. Officers write and edit their own; sergeants and up edit any. |
| **Warrants** | Arrest warrants with reason, charges and expiry. Sergeant and up issue or cancel them; any officer marks one served (an arrest of that person serves it automatically). |
| **Charges** | The penal code (crimes, months, fine, driving points). Pick a person and the crimes: **Fine** (a bank bill) or **Arrest** (booking: photo of the suspect, fingerprint, months; the suspect sees the arrest screen). Both go into the person's record. |
| **Impounds** | Impounded vehicles (reason, fee, hold time, officer) and the evidence locker contents. Impound the car in front of you; release (sergeant+) or the owner pays at the station desk after the hold time. |
| **Licences** | Driver and weapon licences of a person, driving points in the last 30 days. Grant or revoke (weapon licence: sergeant+). The driver licence is suspended by itself at `Config.Licences.maxPoints`. |
| **Evidence** | Evidence bags in your inventory: analyze them at the lab (forensics certification) to turn a casing into a weapon serial, blood into a DNA match and a fingerprint into a person. Results are saved and can go into a report. |
| **Cameras** | The security cameras of shops, banks and the jeweler. Viewing one puts the tablet away; arrows change camera, Backspace leaves. Cameras a robbery cut show as offline. |
| **Certifications** | Each officer's certifications; lieutenants and up give or take them. |
| **Management** | (Chief) hire a nearby player, promote, demote, fire, see each officer's hours this week and in total, last time on duty; write notices for the Dashboard. |

## The field job

- **Stations** (`Config.Stations`, Mission Row and Sandy Shores): clock in/out, armory (a `city_inventory` shop, items by grade), personal locker, evidence locker (stash), trash, garage and helipad, impound desk, forensics lab. All with `ox_target`.
- **Vehicles**: one at a time per officer, from the garage they stand at, models by grade and certification, plate `LSPD####`, keys given.
- **On players** (ox_target on a player, and the radial menu): cuff / uncuff (needs `handcuffs`), soft cuff (can walk), escort, put in / take out of a vehicle, search (`city_inventory` player search), check status (gunpowder, alcohol, smells), scan fingerprint, ankle monitor on/off. Every action is checked on the server (job on duty, distance, the target's state).
- **Cuffed players** can't run, shoot, drive or open the inventory/phone/tablet; the `ishandcuffed` metadata is set on the server. A soft cuff can be broken with a skill check.
- **Objects** (radial menu): cones, barriers, road signs, lights, tent; spike strips burst the tyres of cars that drive over them (max `Config.MaxSpikes` per officer). Pick them up again from the radial menu.
- **Evidence**: shooting drops casings (with the weapon's serial), wounds drop blood, robberies leave fingerprints (no gloves). Officers on duty see them when aiming a flashlight, and pick them up with an `empty_evidence_bag`. Evidence on the ground disappears after `Config.Evidence.minutes`.
- **Ankle monitor**: the person's position shows on the MDT map while it's on.
- **Radars**: fixed speed cameras (km/h). Speeding gives the driver a bank bill; a flagged plate creates a call.
- **Arrest**: the suspect sees an arrest screen with the months and the crimes, the arrest goes in their record, and `city_prison` takes them straight to Bolingbroke ([city-prison.md](city-prison.md)).
- **Panic button** (radial "Emergency"): a high-priority call with the officer's position.

## Calls (dispatch)

`city_police` owns the police calls (`server/dispatch.lua`), in memory, each lasting `Config.Dispatch.minutes`:

- 190 calls: `city_dispatch` calls `exports.city_police:PhoneCall(src, kind, text, caller)`; when the first unit attaches, city_police fires `city_police:server:callAccepted` and the caller hears the police are on the way.
- Scripts: `exports.city_police:Alert({ title, text, coords, code, priority })`, server only.
- Old qbx_police events still work, for the vendored robbery scripts: `police:server:policeAlert`, `evidence:server:CreateFingerDrop`, `evidence:server:CreateBloodDrop`, and on the client `evidence:client:SetStatus` and `police:client:SendPoliceEmergencyAlert` (`server/compat.lua`, `client/compat.lua`). `police:SetCopCount` is still sent to everyone when the number on duty changes.

## Data

Tables, created on start:

| Table | Holds |
| --- | --- |
| `city_police_officers` | citizenid, name, callsign, certifications, minutes on duty, last duty |
| `city_police_shifts` | one row per shift (start, end), for hours per week |
| `city_police_records` | arrests, fines and citations: charges, months, fine, points, officer, booking photo and fingerprint |
| `city_police_reports` | incident reports |
| `city_police_warrants` | warrants: charges, expiry, status |
| `city_police_plates` | flagged plates (stolen / wanted) |
| `city_police_weapons` | registered weapons by serial |
| `city_police_impounds` | impounds: plate, reason, fee, hold until, released |
| `city_police_evidence` | analyzed evidence results |
| `city_police_notices` | the chief's notices |

Licences stay in qbx_core's `metadata.licences`; driving points are summed from records. Vehicles are qbx's `player_vehicles` (an impounded car has `state = 2` until released, then `0`, so it's in the depot).

## Money

Fines, radar tickets and impound fees are **bank bills** (`exports.city_bank:CreateBill`, kind `fine`, split between the treasury and the police account as `city_bank` says). city_police never adds or removes money itself. Cash found on a suspect is taken through the search screen like any item.

## Not in v1

BOLO, K9, body cams, the helicopter camera, court and lawyers, evidence photos.
