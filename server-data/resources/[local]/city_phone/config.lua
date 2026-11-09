Config = {}

-- The item that opens the phone (used from the inventory). The phone always shows its user's own data.
Config.Item = 'phone'

-- A burner phone (city_prison contraband): its own number, calls always hidden, and only these apps
Config.BurnerItem = 'burner_phone'
Config.BurnerApps = { calls = true, messages = true }

-- Choices in Settings. The first of each list is the default.
Config.Themes = { 'dark', 'light' }
Config.Languages = { 'en', 'pt-br' }
Config.Fonts = { 'inter', 'poppins', 'roboto', 'nunito' }
Config.Wallpapers = { 'aurora', 'sunset', 'ocean', 'forest', 'graphite', 'candy' }
Config.Brightness = { min = 30, max = 100 }
-- Phone size in percent (Settings > Appearance, or drag the phone's corner)
Config.Size = { min = 70, max = 130 }
Config.Ringtones = { 'classic', 'marimba', 'chime', 'pulse' }

-- Other players hear a ringing phone up to this far away (meters), quieter with distance
Config.RingDistance = 20.0

-- The player can walk (and drive) with the phone open; these game controls stay off while it is: the mouse camera,
-- attacking and aiming, the weapon wheel and pause. Typing in a text field takes every key until the field loses focus.
Config.BlockedControls = { 1, 2, 24, 25, 37, 44, 45, 140, 141, 142, 257, 263, 264, 199, 200, 16, 17, 68, 69, 70, 91, 92, 106 }

-- Holding the phone
Config.Prop = { model = `prop_npc_phone_02`, bone = 28422, offset = vec3(0.0, 0.0, 0.0), rotation = vec3(0.0, 0.0, 0.0) }
Config.Anims = {
    foot = { dict = 'cellphone@', clip = 'cellphone_text_read_base' },
    car = { dict = 'anim@cellphone@in_car@ps', clip = 'cellphone_text_read_base' },
}

-- Control center flashlight: a light in front of the player while it is on
Config.Flashlight = { distance = 25.0, brightness = 6.0, radius = 22.0, falloff = 12.0 }

-- Notifications kept on the lock screen (this session only)
Config.MaxNotifications = 30
