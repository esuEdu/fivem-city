-- Shared look for every fivem-city screen. Plain data only: other resources load it with
--   local theme = require '@city_ui.theme'
-- and NUI pages turn each key into a CSS variable (accentText -> --accent-text).
return {
    accent = '#f5c542', -- buttons, badges, active tabs, bars
    accentText = '#15181d', -- text and icons drawn on the accent color
    danger = '#e5484d',
    text = '#eef0f3',
    muted = '#8a93a0',

    panel = 'rgba(17, 22, 30, 0.72)',
    section = 'rgba(255, 255, 255, 0.05)',
    slot = 'rgba(10, 14, 20, 0.45)',
    slotHover = 'rgba(255, 255, 255, 0.08)',
    border = 'rgba(255, 255, 255, 0.08)',

    blur = '16px', -- backdrop blur behind panels
    radius = '4px',
    font = "'Segoe UI', Roboto, Arial, sans-serif",
}
