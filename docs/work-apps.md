# Work apps (job and gang tablet apps)

The tablet apps for a job or a gang (Mechanic, EMS and the city_orgs faction apps) share one look with the Staff app and the MDT: a sidebar with the logo, the user's name and grade, the tabs (with red badges) and a footer card, and the content on the right with tiles, cards, tables and list + detail views. The **Mechanic** app (`city_mechanic`) is the first one and the template for the others.

## Shared shell: `city_os/web/kit/workapp.*`

| File | What |
| --- | --- |
| `workapp.css` | Layout and parts: `.wa` shell, `.card`, `.tiles` / `.tile`, `.table-head` / `.table-row`, `.split` (list + detail), `.list-row`, `.info-row`, `.pill`, `.chip`, `.segmented`, `.search`, `.field`, `.bars` chart, `.kit-btn.tint`, toast. Colors come from kit.css (city_ui theme, light/dark). |
| `workapp.js` | `window.WorkApp`: `shell({ ... })` builds the sidebar and tabs; helpers `el`, `icon` / `addIcons`, `L` / `setLabels`, `run(action, args, doneText)`, `toast`, `confirmButton`, `heading`, `pill`, `segmented`, `searchField`, `tile`, `bars`, `avatar`, `money`, `formatTime`, `ago`, `since`. |

Each app picks its color on `:root` in its own CSS: `--app-accent`, `--app-accent-soft`, `--app-accent-text`, `--app-logo` (Mechanic: orange; suggested EMS red, gangs their own color). Nothing else of the shell is copied.

## Making a new one (copy the Mechanic app)

1. **Page** `web/app/`: `index.html` loads `kit.css`, `workapp.css`, `app.css`, `kit.js`, `workapp.js`, then `js/main.js` (module). `main.js` calls `shell({ logo, title, subtitle, tabs, footer })`; each tab is `{ id, icon, label, visible?, badge?, render(args) }` and `render` returns the node to show. `CityOS.on('open', args)` opens a tab from a tapped notification; `CityOS.on('message')` refreshes.
2. **Client** `client/app.lua`: one `run` NUI callback with a list of allowed actions, each forwarded to `lib.callback.await('<resource>:app:<action>')`; `labels = lib.getLocales()` added to the `app` answer. Client-only data (street names) is filled in here.
3. **Server** `server/app/`: `core.lua` registers the app with `exports.city_os:RegisterApp` (`access = { jobs = { [job] = 0 } }`, or `gangs`) and wraps every callback (`core.register(name, handler, { boss = true })`: the player must have the job, `isboss` for boss actions). `team.lua` (members with grade, status and week count; job offer by server id that the player accepts on screen, grade change below the boss's grade, fire) works for any job by changing `Config.Job`; for a gang use the `gang` group type and qbx's gang exports.
4. **Strings** in `locales/en.json` (`ui_*`, `error_*`; the shell needs `ui_loading`, `ui_sure`, `ui_just_now`, `ui_minutes_ago`, `ui_hours_ago`, `ui_days_ago`).
5. **Calls**: a job that answers phone calls through `city_dispatch` lists them with its callbacks (`city_dispatch:calls`, `respond`, `close`) from the client, and listens to the server event `city_dispatch:server:callsChanged(service, id?)` (new call: `id` set) to notify with `exports.city_os:Notify` and set the badge (`exports.city_dispatch:OpenCount(service)`).

## Mechanic app tabs

- **Dashboard**: on duty, open 555 calls, services today (and their value), the viewer's services this week, a 7-day chart, who is on duty, latest services.
- **Calls**: the open 555 calls (off duty: a notice to clock in). Respond sets the GPS; whoever responds can close the call. A new call notifies mechanics on duty on the tablet and the app icon shows the open count.
- **Management**: every mechanic (hired, online or not) with grade, status and services this week, for the whole team. The boss (`isboss` grade) taps Hire and types a server id: the player gets a job offer on their screen (ox_lib dialog, `Config.App.offerSeconds`) and starts at the lowest grade if they accept; the boss hears the answer. The boss also changes grades (a list of the grades below their own) and fires, with a confirm.
- **Services**: the tuning bay's history (`city_mechanic_services`: plate, mechanic, parts, value, repaired, staff), searchable by plate or mechanic, and the reference price list from `Config.Prices` to charge customers.

The MDT (`city_police`) has the same Management tab: every officer sees it, the chief (`Config.Permissions.management`) sends job offers by server id (`Config.OfferSeconds`), changes ranks and fires.

## EMS app (`city_hospital`)

A copy of the Mechanic app in red: Dashboard (on duty, open calls, revives today and amount billed, the viewer's records this week, 7-day chart), Calls (SOS, 192, emergency button and officer down from `server/sos.lua`; accept sets the GPS and tells a downed patient who is coming, whoever accepted closes it), Management (the same job offers, grade changes and firing) and Records (`city_hospital_records`: every revive and bill by an EMS, searchable by patient or EMS, plus the reference prices in `server/config.lua` `billing`).
