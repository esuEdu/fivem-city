# City OS (`city_os`): design

The iFruit Pad: a tablet players hold in game. `city_os` is **only the tablet**; every app is its own `city_<feature>` resource that registers with it. Mockup: https://claude.ai/artifact/Pe7CCxaY8erYh6scZiXrBZ

## What `city_os` contains

- The `tablet` item, opening it (use the item, or `Config.OpenKey` while carrying one), the hold-tablet animation with `prop_cs_tablet`, and closing it.
- Lock screen (swipe up), passcode screen, home screen (widgets, one app grid that scrolls when the apps don't fit, dock), notification center (pull down from the top), notification banners, the home bar.
- The built-in **Settings** app: wallpaper, appearance (light/dark), icon style (color/clear/tinted), app labels, widgets, badges, dock, notifications per app, text size, bold text, reduce motion, passcode, about (serial).
- The app registry, notifications, badges and unlocks (exports below), and the shared UI kit apps use.
- Empty states: no apps yet; an app whose resource stopped ("isn't available").

No app logic lives in `city_os`. Profile, the job MDTs, Staff, Burner, Garage, Races, Festival and anything else are separate resources.

## Apps

### Registering (server side)

Apps register on the **server**, so who may see them is decided there:

```lua
exports.city_os:RegisterApp({
    id = 'police_mdt',                 -- unique; prefix with the feature
    label = 'Police',
    page = 'web/index.html',           -- in the calling resource; loaded as https://cfx-nui-<resource>/web/index.html
    icon = {
        glyph = 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z',  -- SVG path data, 24x24, drawn as a stroke
        colors = { '#7aa8ff', '#3f74f0', '#2149b8' },          -- Color style gradient, light to dark
        glyphColor = '#ffffff',        -- glyph on the Color style
        tint = '#8fb4ff',              -- glyph on the Tinted style
    },
    access = {                         -- nil = everyone; otherwise any one rule is enough
        jobs = { police = 0 },         -- job -> lowest grade
        gangs = nil,                   -- gang -> lowest grade
        staff = nil,                   -- an ACE such as 'mod'; also needs admin duty (IsOptin)
        unlock = nil,                  -- an unlock key: hidden until exports.city_os:Unlock gives it
    },
    order = 20,                        -- place on the home screen
})
```

- The icon is a **glyph plus colors**, not an image, so Color, Clear and Tinted work for every app.
- Registrations from a resource are removed when it stops (`onResourceStop`); an open app then shows "isn't available".
- `access.unlock` apps never appear on the home screen, in the dock, in notifications or on the lock screen until unlocked, so a police search of the tablet shows nothing.

### Who sees what

When a player opens the tablet, the client asks the server (`lib.callback`) for **their** apps. The server filters the registry by the holder's job/grade, gang, staff ACE + `IsOptin`, and unlocks (stored per citizenid). Apps follow **the person holding the tablet**, not its owner: a stolen police tablet shows no MDT to a civilian.

Hiding an app is only UX. Every app's own server events still check job/grade/staff themselves (`docs/standards/security.md`).

### How an app's page runs

- Each app page runs in its **own iframe** inside the tablet page, created when opened and removed a while after it closes, so apps can't break each other or the tablet.
- **Page → its own Lua**: `fetch('https://<resource>/<callback>', ...)` reaches that resource's `RegisterNUICallback`, as normal NUI.
- **Lua → its page**: `exports.city_os:SendAppMessage(appId, data)` (client); `city_os` forwards it into the app's iframe. A plain `SendNUIMessage` from the app resource doesn't reach a page inside another resource's NUI.
- **Tablet → page**: `city_os` posts `{ type = 'theme' }` (appearance, icon style, text size, city_ui colors) and `{ type = 'open', args }` (e.g. the dispatch call a notification was tapped for).

### Shared UI kit

`city_os/web/kit/kit.css` and `kit.js`, loaded by every app page from `https://cfx-nui-city_os/web/kit/...`:

- The pieces from the mockup: app sidebar, list groups and rows, switches, buttons, pills, cards, segmented control, search field, empty/error states.
- Colors as CSS variables for light and dark (`--fg`, `--muted`, `--group`, `--row`, ...), built from `city_ui/theme.lua` plus the appearance setting. No `backdrop-filter` (FiveM draws it black).
- `kit.js`: applies the theme messages, and helpers `CityOS.send(event, data)` (fetch to the app's own resource), `CityOS.on(type, fn)`, `CityOS.close()` (back to home).

## Notifications, badges, unlocks (server exports)

```lua
exports.city_os:Notify(src, {
    app = 'police_mdt', title = '10-90 Store robbery', body = '24/7, Innocence Blvd',
    banner = true,                     -- drop-down banner while the tablet is open (dispatch)
    open = { tab = 'dispatch', call = 42 },  -- passed to the app when the notification is tapped
})
exports.city_os:SetBadge(src, 'police_mdt', 3)   -- 0 clears it
exports.city_os:Unlock(citizenid, 'burner')      -- shows apps with access.unlock = 'burner'
```

- Notifications are kept in memory per citizenid (last `Config.MaxNotifications`), shown on the lock screen (except hidden apps), in the notification center and as badges; lost on restart.
- Per-app on/off in Settings → Notifications is a display preference, applied on the tablet page (it's per tablet, and a player may carry several). A notification for an app the player can't see is refused on the server (`no_access`), so hidden apps never give themselves away.
- Send to the players who need it (job members on duty), never `-1`.

## The tablet item and its data

- `tablet` item, `stack = false`, metadata `{ serial = 'IFP-48213-KX' }`. The serial ties a found or stolen tablet to its owner.
- Settings, the passcode (hashed) and the owner are stored on the server in `city_os_tablets` (`serial` primary key, `owner` citizenid, `code_hash`, `settings` JSON), not in item metadata, because metadata is sent to clients.
- Settings travel with the tablet; apps follow whoever holds it (above).
- **Own picture as wallpaper**: the player pastes an image link (`https://` only, no quotes, brackets, backslashes or spaces, at most 480 characters, checked again in Lua before saving). It is stored **only on the player's computer** with client `SetResourceKvp` and is **never sent to the server** or to other players; it is not part of the tablet's server settings, so it stays on that PC whichever tablet is used. FiveM's NUI can't open a file picker, so a link is the only way in.
- Passcode: checked on the server with `VerifyPasswordHash`, rate-limited per tablet (3 tries, then a 30 s wait; closing and reopening doesn't reset it). Resetting a forgotten code (staff) comes later.
- Several tablets in one inventory: the one in the lowest slot opens.

## Opening, closing, input

- Opening is checked on the server (holds a `tablet`, not dead/cuffed). Plays the hold animation; NUI focus with mouse.
- `Esc` / `Backspace`: in an app, back to home; on home, close the tablet. The home bar also goes home.
- Closing removes the prop and focus; the tablet locks again when `Lock when put away` is on.

## Performance

- Nothing runs while the tablet is closed except the keybind and item use (no loops).
- App iframes load on open and are dropped after `Config.AppIdleSeconds` closed.
- Notifications and badges are sent as changes to one player, not as broadcasts.

## Config (`config.lua`)

`Config.OpenKey`, `Config.Item = 'tablet'`, `Config.DefaultWallpaper`, `Config.DefaultAppearance = 'dark'`, `Config.DefaultIconStyle = 'color'`, `Config.Wallpapers`, `Config.DockSize = 6`, `Config.MaxNotifications = 50`, `Config.AppIdleSeconds = 120`, `Config.CodeTries = 3`, `Config.CodeWaitSeconds = 30`.

## Decided for v1

- Open key: **F2** (free: seatbelt is B, emote menu F5, vehicle radio F9, phone M).
- The player **stands still** while the tablet is in hand (keyboard and mouse go to the tablet); walking with it can come later.
- **No battery** in v1: the status bar shows the time only.
- **Widgets from apps** (`RegisterWidget`, e.g. the duty widget) come after the first apps work; v1 has the built-in clock widget.
