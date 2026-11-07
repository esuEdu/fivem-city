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
| mod | + spectate, open inventory, cuff, kick, ban up to `Config.MaxBanHours` (7 days), noclip, invisible, names, blips |
| admin | + longer and permanent bans, unban, staff log, Team tab, kill, clothing menu, routing bucket, set job/gang, armor/hunger/thirst, godmode, spawn vehicles |

## Tabs

- **Dashboard**: open reports (and how long the oldest has waited), reports closed, average first reply and the staff rating for Today / Week / Month; a chart of reports sent vs closed over the last 7 days; your own card (closed vs the goal admins set in Team, rank, rating, reply time); the team table (who's online, closed, rating, first reply); the latest ratings.
- **Players**: list on the left (job, time online, health bar), the selected player on the right: health, armor, cash, bank, job, gang, location (street, worked out on the staff member's client), vehicle and plate, ping, bucket, license, status pills, the actions (Freeze and Cuff light up while on, Revive while the player is down; Heal cures wounds and bleeding only; Revive brings a downed player back, or fills a living one to full health), the **Character** card (job, gang, armor, hunger, thirst, bucket: each shows its current value, Edit opens a searchable picker or slider, and a Review step shows old → new before it applies; Fire sets unemployed / no gang), warn/kick/ban with a reason, and their last 20 warnings.
- **Reports**: from `/report <message>` (anyone; one per `Config.ReportCooldown`). Online staff get a banner and a badge on the app icon. Open / Mine / Closed; each report is a conversation: claim, reply (the player gets a notification), go to or bring the player, **Close and ask for rating**. Saved in `city_staff_reports`, so open reports survive a restart (their senders show as offline).
- **Ratings**: when staff close a report and the sender is online, the sender gets a prompt (this resource's `ui_page`, `web/prompt.html`): 1–5 stars, tags from `Config.RatingTags`, an optional comment, or Skip. The server only takes a rating it asked for, from that player, once, within `Config.RatingMinutes`. The tab shows the last 30 days: overall score, how many of each star, each staff member's rating and trend (vs the 30 days before), and the comments. Every staff level sees it (`Config.Permissions.ratings`).
- **Team** (admins, `Config.Permissions.team`): every staff member with activity in Today / Week / Month, or online now: reports closed, rating, first reply, actions and sanctions from the staff log, last active. A person's page: those numbers, a 14-day chart of reports they answered first and closed, what they did (actions by type), their rating spread and latest ratings, and their last 30 logged actions. Staff are told apart by license, so one person's characters count together. Admins set the report goals here (**Goals**: per day, week and month; `Config.Permissions.goals`); they're saved in the server's resource storage (KVP), start from `Config.Goals`, and drive the goal ring on the Dashboard and each person's progress bar in the list.
- **Bans**: active bans from qbx_core's `bans` table, with Unban for admins. Bans made in txAdmin's panel live in txAdmin and aren't listed.
- **Staff log**: the last `Config.LogLimit` staff actions, searchable (admins).
- **My tools**: noclip, invisible, godmode, names over heads, map blips; spawn a vehicle (by model name from qbx_core's vehicle list).

**No staff commands in game**: everything is in the app. The only command left here is `/report` for players (to become an app or a key later). The qbx_core patch also removes qbx_core's admin commands (`/tp`, `/tpm`, `/car`, `/dv`, `/setjob`, `/changejob`, `/addjob`, `/removejob`, `/setgang`, `/givemoney`, `/setmoney`, `/addpermission`, `/removepermission`, `/openserver`, `/closeserver`, `/togglepvp`, `/logout`, `/deletechar`, `/optin`); players keep `/job`, `/gang`, `/ooc`, `/me`, `/id`. Staff levels are set in `server.cfg` (`add_principal`) or txAdmin, not in game.

## Data

- **Warnings**: `city_staff_warnings` (citizenid, license, reason, staff name, time). The player sees a dialog with the reason.
- **Bans**: rows in qbx_core's `bans` (license, discord, ip, reason, expire, bannedby); qbx_core refuses the connection while `expire` is in the future. Permanent = `expire` 2147483647. IPs are stored for the check but never sent to the app.
- **Staff log**: `city_staff_log`, one row per action (staff, action, target, details, time).
- **Reports and ratings**: `city_staff_reports`, one row per report: sender, message, replies (JSON), when it was sent, first claimed or answered (`response_at`, for reply times), who claimed and closed it (name, license, level), and the rating (stars, tags, comment, time). All three tables are created on start.

## How tools work

- Spectate: the staff member joins the target's routing bucket, hides under them and follows every second so the target stays streamed in; Backspace stops and puts them back (place and bucket).
- Noclip, invisible, godmode, names and blips run on the staff member's client after the server says yes and logs it. Blips: the server sends every player's position every `Config.BlipSeconds` to staff with blips on, and stops when nobody has them on.
- Open inventory closes the tablet and opens city_inventory's player search; city_inventory checks `Config.SearchStaffAce` (`mod`) again.
- Cuff uses qbx_police's own cuff event; clothing opens illenium-appearance's menu on the target.

## txAdmin

Turn off txAdmin's in-game menu so staff use one tool: in txAdmin's web panel, **Settings → Game**, turn off the in-game menu option (then restart the server). Its web panel (players, kick, ban, warn) keeps working for whoever runs the server.

## Not in v1

Dev tools (copy coords), weather/time, radio list, pull stash, give all weapons, set money (money only moves through city_economy), ped model, offline bans, resetting a forgotten tablet passcode.
