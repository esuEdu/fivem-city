dofile('harness.lua')

local settings = require 'shared.settings'

-- Nothing sent: the defaults
local s = settings.sanitize(nil)
assert(s.wallpaper == 'sunset' and s.appearance == 'dark' and s.iconStyle == 'color' and s.labels == true)
assert(#s.dock == 0 and next(s.muted) == nil)

-- Good values are kept, bad ones fall back
s = settings.sanitize({ wallpaper = 'neon', appearance = 'light', iconStyle = 'tinted', textSize = 'large', labels = false, bold = true })
assert(s.wallpaper == 'neon' and s.appearance == 'light' and s.iconStyle == 'tinted' and s.textSize == 'large' and s.labels == false and s.bold == true)

s = settings.sanitize({ wallpaper = 'url(evil)', appearance = 'pink', iconStyle = 1, textSize = {}, labels = 'yes', extra = 'x' })
assert(s.wallpaper == 'sunset' and s.appearance == 'dark' and s.iconStyle == 'color' and s.textSize == 'default' and s.labels == true)
assert(s.extra == nil)
assert(settings.sanitize({ wallpaper = 'custom' }).wallpaper == 'custom')

-- Dock: valid ids, no duplicates, at most Config.DockSize
s = settings.sanitize({ dock = { 'police_mdt', 'police_mdt', 'bad id!', 42, 'a', 'b', 'c', 'd', 'e', 'f', 'g' } })
assert(#s.dock == Config.DockSize and s.dock[1] == 'police_mdt' and s.dock[2] == 'a')

-- Muted apps: only true flags on valid ids
s = settings.sanitize({ muted = { burner = true, bank = false, ['x y'] = true } })
assert(s.muted.burner == true and s.muted.bank == nil and s.muted['x y'] == nil)

-- Own wallpaper links
assert(settings.isWallpaperUrl('https://i.imgur.com/abc123.png'))
for _, bad in ipairs({ 'http://i.imgur.com/a.png', 'javascript:alert(1)', 'https://x.com/a.png");}body{', 'https://x.com/a b.png', 'https://x', 'https://' .. ('a'):rep(480), 42 }) do
    assert(not settings.isWallpaperUrl(bad), tostring(bad))
end

-- Codes
assert(settings.isCode('0420'))
for _, bad in ipairs({ '123', '12345', 'abcd', 1234, '12 4' }) do
    assert(not settings.isCode(bad), tostring(bad))
end
