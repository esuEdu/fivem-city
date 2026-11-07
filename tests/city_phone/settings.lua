dofile('harness.lua')

local settings = require 'shared.settings'

-- Only known keys with allowed values
check(settings.valid('theme', 'light'), 'light theme is allowed')
check(not settings.valid('theme', 'neon'), 'unknown theme is refused')
check(settings.valid('language', 'pt-br'), 'Portuguese is allowed')
check(not settings.valid('language', 'fr'), 'unknown language is refused')
check(settings.valid('font', 'nunito'), 'known font is allowed')
check(settings.valid('wallpaper', 'ocean'), 'known wallpaper is allowed')
check(not settings.valid('wallpaper', 'https://example.com/x.png'), 'a picture URL is refused')
check(settings.valid('silent', true) and settings.valid('dnd', false), 'switches take booleans')
check(not settings.valid('silent', 'yes'), 'a switch refuses strings')
check(not settings.valid('money', 1), 'unknown key is refused')
check(not settings.valid(nil, 1), 'missing key is refused')

-- Brightness: whole numbers in range
check(settings.valid('brightness', 30) and settings.valid('brightness', 100), 'brightness limits are allowed')
check(not settings.valid('brightness', 29), 'too dark is refused')
check(not settings.valid('brightness', 101), 'too bright is refused')
check(not settings.valid('brightness', 50.5), 'fractions are refused')

-- Saved data is cleaned: defaults for anything missing or wrong, unknown keys dropped
local clean = settings.clean({ theme = 'light', font = 'comic', extra = 'x' })
check(clean.theme == 'light', 'valid saved value kept')
check(clean.font == 'inter', 'invalid saved value back to default')
check(clean.language == 'en' and clean.wallpaper == 'aurora', 'missing values get defaults')
check(clean.extra == nil, 'unknown keys are dropped')
check(settings.clean(nil).brightness == 100, 'no saved settings gives full defaults')

finish()
