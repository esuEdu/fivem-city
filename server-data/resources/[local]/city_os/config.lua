Config = {}

-- The tablet item (data/items.lua in city_inventory) and the key that opens it while carrying one
Config.Item = 'tablet'
Config.OpenKey = 'F2'

-- Hold-tablet animation and prop while it's open
Config.Animation = { dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', clip = 'base' }
Config.Prop = { model = `prop_cs_tablet`, bone = 60309, offset = vector3(0.03, 0.002, -0.0), rotation = vector3(10.0, 160.0, 0.0) }

-- Device colors players pick in Settings. frame/edge color the tablet on screen; in the player's hand each color uses
-- `tint` (a texture variation of Config.Prop.model, if the model has them: find them in game with /tablettint) or
-- `model` (its own prop, e.g. a streamed recolored tablet). Other players see the same color.
Config.DeviceColors = {
    { id = 'graphite', label = 'Graphite', frame = { '#2c2f36', '#0c0d10', '#1a1c21' }, edge = '#4a4e57', tint = 0 },
    { id = 'silver', label = 'Silver', frame = { '#eef0f3', '#b6bac3', '#d6d9df' }, edge = '#f7f8fa', tint = 1 },
    { id = 'gold', label = 'Gold', frame = { '#f3e0bb', '#c39e63', '#e2c799' }, edge = '#f8ead0', tint = 2 },
    { id = 'blue', label = 'Sky blue', frame = { '#6e93c9', '#2b4570', '#4766a0' }, edge = '#8fb0de', tint = 3 },
    { id = 'green', label = 'Sage', frame = { '#8db39a', '#3d5e4a', '#5d8670' }, edge = '#a9cdb5', tint = 4 },
}

-- Wallpapers players can pick; each is a CSS background. 'custom' (the player's own picture) is added by the tablet.
Config.Wallpapers = {
    { id = 'sunset', label = 'Sunset', css = 'radial-gradient(55% 65% at 12% 18%, rgba(245, 197, 66, 0.55), transparent 62%), radial-gradient(45% 55% at 88% 22%, rgba(64, 118, 255, 0.5), transparent 62%), radial-gradient(65% 55% at 62% 104%, rgba(255, 112, 56, 0.42), transparent 62%), linear-gradient(160deg, #151a29, #0a0c13)' },
    { id = 'ocean', label = 'Ocean', css = 'radial-gradient(60% 70% at 20% 15%, rgba(62, 207, 180, 0.5), transparent 62%), radial-gradient(55% 60% at 85% 85%, rgba(40, 110, 255, 0.55), transparent 62%), linear-gradient(170deg, #0d1f2a, #070b14)' },
    { id = 'night', label = 'Night drive', css = 'radial-gradient(50% 60% at 80% 20%, rgba(139, 108, 246, 0.55), transparent 62%), radial-gradient(60% 50% at 15% 90%, rgba(229, 72, 77, 0.4), transparent 62%), linear-gradient(160deg, #120f24, #07060d)' },
    { id = 'neon', label = 'Neon', css = 'radial-gradient(45% 55% at 15% 25%, rgba(255, 64, 160, 0.5), transparent 62%), radial-gradient(50% 60% at 85% 75%, rgba(0, 220, 255, 0.45), transparent 62%), linear-gradient(160deg, #1a0f22, #06080d)' },
}

-- Defaults for a new tablet (players change them in Settings)
Config.DefaultSettings = {
    wallpaper = 'sunset',
    deviceColor = 'graphite',
    appearance = 'dark', -- dark | light
    iconStyle = 'color', -- color | clear | tinted
    textSize = 'default', -- small | default | large
    labels = true,
    widgets = true,
    badges = true,
    lockNotes = true,
    bold = false,
    motion = true,
}

Config.DockSize = 6
Config.MaxNotifications = 50

-- How long a notification banner stays on screen, and how long a closed app stays loaded before it's dropped
Config.BannerSeconds = 5
Config.AppIdleSeconds = 120

-- Passcode: wrong tries before the tablet makes the player wait
Config.CodeTries = 3
Config.CodeWaitSeconds = 30
