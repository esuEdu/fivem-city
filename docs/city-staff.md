# Staff app (`city_staff`)

The **Staff** app on the iFruit tablet, and the staff commands around it. It replaced `qbx_adminmenu` and is meant to replace txAdmin's **in-game** menu too; txAdmin's web panel stays for running the server (console, restarts, backups).

## Who can use it

- Staff levels are ACEs from `server.cfg`: `support` < `mod` < `admin` (`group.admin` includes `group.mod`, which includes `group.support`). Give someone a level with `add_principal identifier.license:<license> group.mod`.
- There is **no admin duty**: qbx_core's `requireOptIn` is off and `/optin` is removed (`scripts/patches/qbx_core.patch`), so the level applies whenever the player is online. ACEs are per account (license), not per character: staff play as a separate **staff character** by convention, but their tools work on every character of that account.
- The app shows on the tablet for anyone with `support` or higher (`access.staff = 'support'`). Staff need a `tablet` item (`/giveitem <id> tablet 1`, or from the server console).
- What each level may do is `Config.Permissions` (action → lowest level). Every server callback checks it again (`server/staff.lua` `staff.register`), so hiding a button is only UX.
- Staff can't freeze, kill, cuff, warn, kick, ban or move a player who is staff at their own level or above.

| Level | Can |
| --- | --- |
| support | player list, reports, go to, bring, heal, revive, freeze, warn |
| mod | + spectate, open inventory, cuff, kick, ban up to `Config.MaxBanHours` (7 days), noclip, invisible, names, blips, fix and delete vehicles |
| admin | + longer and permanent bans, unban, staff log, kill, clothing menu, routing bucket, set job/gang, godmode, spawn vehicles, save a vehicle to their garage |

## Tabs

- **Players**: everyone online, searchable by id, name or citizen id. A player's page has their info (job, gang, ping, bucket, license, status), the actions, job/gang/bucket forms, warn/kick/ban with a reason, and their last 20 warnings.
- **Reports**: from `/report <message>` (anyone; one per `Config.ReportCooldown`). Online staff get a banner and a badge on the app icon. Claim, reply (the player gets a notification), go to the player, close. Kept in memory only, lost on restart.
- **Bans**: active bans from qbx_core's `bans` table, with Unban for admins. Bans made in txAdmin's panel live in txAdmin and aren't listed.
- **Staff log**: the last `Config.LogLimit` staff actions, searchable (admins).
- **My tools**: noclip, invisible, godmode, names over heads, map blips; spawn (by model name from qbx_core's vehicle list), fix, delete and save vehicles.

**No staff commands in game**: everything is in the app. The only command left here is `/report` for players (to become an app or a key later). The qbx_core patch also removes qbx_core's admin commands (`/tp`, `/tpm`, `/car`, `/dv`, `/setjob`, `/changejob`, `/addjob`, `/removejob`, `/setgang`, `/givemoney`, `/setmoney`, `/addpermission`, `/removepermission`, `/openserver`, `/closeserver`, `/togglepvp`, `/logout`, `/deletechar`, `/optin`); players keep `/job`, `/gang`, `/ooc`, `/me`, `/id`. Staff levels are set in `server.cfg` (`add_principal`) or txAdmin, not in game.

## Data

- **Warnings**: `city_staff_warnings` (citizenid, license, reason, staff name, time). The player sees a dialog with the reason.
- **Bans**: rows in qbx_core's `bans` (license, discord, ip, reason, expire, bannedby); qbx_core refuses the connection while `expire` is in the future. Permanent = `expire` 2147483647. IPs are stored for the check but never sent to the app.
- **Staff log**: `city_staff_log`, one row per action (staff, action, target, details, time). Both tables are created on start.

## How tools work

- Spectate: the staff member joins the target's routing bucket, hides under them and follows every second so the target stays streamed in; Backspace stops and puts them back (place and bucket).
- Noclip, invisible, godmode, names and blips run on the staff member's client after the server says yes and logs it. Blips: the server sends every player's position every `Config.BlipSeconds` to staff with blips on, and stops when nobody has them on.
- Open inventory closes the tablet and opens city_inventory's player search; city_inventory checks `Config.SearchStaffAce` (`mod`) again.
- Cuff uses qbx_police's own cuff event; clothing opens illenium-appearance's menu on the target.

## txAdmin

Turn off txAdmin's in-game menu so staff use one tool: in txAdmin's web panel, **Settings → Game**, turn off the in-game menu option (then restart the server). Its web panel (players, kick, ban, warn) keeps working for whoever runs the server.

## Not in v1

Dev tools (copy coords), weather/time, radio list, pull stash, give all weapons, set money (money only moves through city_economy), ped model, offline bans, resetting a forgotten tablet passcode.
