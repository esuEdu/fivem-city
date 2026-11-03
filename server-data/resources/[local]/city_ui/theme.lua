-- Shared look for every fivem-city screen. Plain data only: other resources load it with
--   local theme = require '@city_ui.theme'
-- and NUI pages turn each key into a CSS variable (accentText -> --accent-text).
return {
    accent = '#f5c542', -- buttons, badges, active tabs, bars
    accentText = '#15181d', -- text and icons drawn on the accent color
    accentGlow = 'rgba(245, 197, 66, 0.7)', -- neon glow around accent elements
    danger = '#e5484d',
    text = '#eef0f3',
    muted = '#8a93a0',

    panel = 'rgba(8, 10, 18, 0.78)',
    section = 'rgba(255, 255, 255, 0.04)',
    slot = 'rgba(6, 8, 14, 0.55)',
    slotHover = 'rgba(255, 255, 255, 0.06)',
    border = 'rgba(255, 255, 255, 0.07)',

    blur = '16px', -- backdrop blur behind panels
    radius = '4px',
    font = "'Segoe UI', Roboto, Arial, sans-serif",
}
