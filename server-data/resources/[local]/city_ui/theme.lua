-- Shared look for every fivem-city screen. Plain data only: other resources load it with
--   local theme = require '@city_ui.theme'
-- and NUI pages turn each key into a CSS variable (accentText -> --accent-text).
return {
    accent = '#f5c542', -- buttons, badges, active tabs, bars
    accentText = '#15181d', -- text and icons drawn on the accent color
    accentGlow = 'rgba(245, 197, 66, 0.45)', -- soft glow around accent elements
    accentSoft = 'rgba(245, 197, 66, 0.1)', -- faint accent tint (card background, selected slot)
    danger = '#e5484d',
    text = '#eef0f3',
    muted = '#7d8590',

    panel = 'rgba(12, 13, 18, 0.82)',
    section = 'rgba(255, 255, 255, 0.035)',
    slot = 'rgba(255, 255, 255, 0.03)',
    slotHover = 'rgba(255, 255, 255, 0.07)',
    border = 'rgba(255, 255, 255, 0.06)',

    blur = '18px', -- backdrop blur behind panels
    radius = '10px', -- buttons, slots, inputs
    radiusLarge = '22px', -- panels and cards
    font = "'Poppins', 'Segoe UI', Roboto, Arial, sans-serif",
    mono = "'JetBrains Mono', Consolas, monospace", -- weights and counts
}
