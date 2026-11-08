Config = {}

-- Who may build: an ACE (server.cfg: add_ace group.admin admin allow), plus admin duty (IsOptin)
Config.Ace = 'admin'

-- The tablet app
Config.App = {
    id = 'builder',
    label = 'Builder',
    order = 92,
    icon = {
        glyph = 'M3 21h18M5 21V10l7-5 7 5v11M9 21v-6h6v6',
        colors = { '#ffd36b', '#f5a524', '#c26d06' },
        glyphColor = '#ffffff',
        tint = '#ffc65a',
    },
}

-- Props are spawned on each client (not networked) within this many metres of the camera
Config.RenderDistance = 150.0

-- The freecam can't go further than this from the builder's character (also checked on the server)
Config.MaxCamDistance = 250.0

-- Freecam speed in metres per second; Shift multiplies it, Alt divides it
Config.CamSpeed = 8.0
Config.CamFast = 5.0
Config.CamSlow = 5.0
Config.MouseSensitivity = 6.0

-- Keyboard steps in the editor: normal and with Shift held (fine)
Config.MoveStep = 0.1
Config.MoveStepFine = 0.01
Config.RotateStep = 5.0
Config.RotateStepFine = 1.0

-- Map props hidden within this radius of the clicked one's position (same model only)
Config.HideRadius = 1.0

-- Limits
Config.MaxProps = 10000
Config.MaxGroups = 200
Config.MaxGroupOffset = 100.0

-- Server-side rate limit: changes per player per second
Config.OpsPerSecond = 8

-- The placed props list shows this many, nearest first
Config.ListLimit = 200
