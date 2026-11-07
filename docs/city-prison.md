# city_prison

Bolingbroke Penitentiary. Replaces xt-prison. Decisions were made with the server owner in a quiz (November 2026).

## Going in

- An arrest in the MDT (city_police, `server/mdt/charges.lua`) calls `exports.city_prison:Jail(src, months, officer)`. The screen fades and the suspect wakes up in the cell block; there is no transport to the prison.
- Months owed from an earlier escape are added. The total is capped at `maxMonths`.
- The inmate is uncuffed, taken off duty (and can't clock in while inside) and dressed in the uniform (`Config.Uniform`).
- **Belongings**: everything goes to a per-character stash, `city_prison_locker:<citizenid>`. Illegal items (`illegal` in `server/config.lua`) and every weapon that is not registered to the inmate in the MDT go to `city_police_evidence` instead, for good. Cash is the player's ledger balance (city_economy) and stays in the pocket.
- Logging out keeps the sentence; logging in while serving puts the player straight back inside.

## Serving

- One month is one minute played inside, counted on the server (`secondsPerMonth`). Offline time doesn't count.
- A counter in the top-right corner shows the months left.
- **Jobs** (the board in the cell block): cleaning, kitchen and electrical (with a skill check). Each finished spot takes months off (`jobs` in `server/config.lua`), never more than half the sentence in total (`reduceCap`). The server starts and finishes every task, checking the spot and the time.
- **Food and water**: water fountains and a food tray in the canteen raise thirst and hunger directly, with a cooldown per inmate. There is no canteen NPC or doctor.
- **Contraband**: hidden spots give parts (scrap, cloth, wire, battery, circuit board) with a chance; a spot that was just searched is empty for a while. Parts combine in the inventory (city_inventory `Config.Recipes`):
  - 2 scrap + 1 cloth → shank (`weapon_switchblade`)
  - 2 wire + 1 scrap → improvised jammer (`prison_jammer`), which hacks gate terminals like a trojan USB
  - 1 battery + 1 circuit board → burner phone (`burner_phone`)
- **Burner phone**: opens city_phone with a number of its own (11 digits starting with `000`, kept in the item's metadata), so nobody can tell who it is. Calls from it are always hidden; replies to its messages reach whoever carries it. Only the Phone and Messages apps are shown (`Config.BurnerApps` in city_phone), no Settings. Using the normal phone again leaves burner mode.
- **Dying inside**: city_hospital's respawn sends the inmate to the prison infirmary, free, without losing what they carry.

## Getting out

- When the time is up the counter says so; the inmate goes to the release desk. Whatever was made or found inside is taken (cash stays), the locker comes back and the player is let out at the gate with their own clothes. What doesn't fit stays in the locker; "Collect belongings" at the same desk gives it back later.
- Police can set the time to zero on the prison computer; the inmate still walks out through the desk.

## Escapes

- Gate terminals (`Config.Terminals`) need a jammer or a trojan USB, a progress bar and a skill check. Success opens the gate (an ox_doorlock door, created by name on start if missing) for `openSeconds`. The alarm and losing the item are chances (`hack` in `server/config.lua`); the alarm sounds around the prison and the police get a call. Anyone can hack, from inside or outside.
- The server checks every few seconds whether an inmate is outside the prison circle (`Config.Prison`). That is the escape: the time left times `escapeMultiplier` is owed, the police get a call and an MDT warrant (`exports.city_police:IssueWarrant`) for `warrantDays`. The next arrest serves the warrant and adds the debt.
- Walking out with the time already served is not an escape; the belongings wait at the desk.

## Prison computer

At the front desk, for police on duty. Grades per action are `Config.ComputerGrades`:

| Action | What it does |
|---|---|
| view | Inmates serving (time left, sentence, reduced, online) and escapees (months owed), and the log |
| setTime | Change the time left (works offline) |
| release | Time left to zero; the inmate leaves through the desk |
| clearEscape | Forget an escape debt |

## Data

- `city_prison_inmates`: one row per character serving or owing time.
- `city_prison_log`: jailed, released, escaped, set_time, cleared.
- xt-prison's `xt_prison` and `xt_prison_items` tables are no longer read and stay in the database untouched. Anyone who was in xt-prison is free, and items it confiscated stay in `xt_prison_items`.

## Coordinates to check in game

Infirmary, job board, job spots, fountains, contraband spots and the gate doors were placed without the game open (`-- check` in `config.lua`). The spawns, desk, computer, terminals and the circle come from xt-prison.
