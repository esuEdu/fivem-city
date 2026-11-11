-- Reading and changing the pieces a shop sells on the player's ped (the preview; only the server saves)
local catalog = require 'shared.tattoos'

local look = {}

---The tattoos on the ped while a shop is open: [zone] = { { name, opacity } }. The game can't be asked which
---decorations a ped has, so the shop keeps the list and redraws all of them on every change.
look.tattoos = {}

local OVERLAY_NAMES = { [1] = 'beard', [2] = 'eyebrows', [4] = 'makeUp', [5] = 'blush', [8] = 'lipstick', [10] = 'chestHair' }
local COLOR_TYPE = { hair = 1, makeup = 2 }

look.OVERLAY_NAMES = OVERLAY_NAMES

function look.sex()
    return GetEntityModel(cache.ped) == `mp_f_freemode_01` and 'f' or 'm'
end

function look.isFreemode()
    local model = GetEntityModel(cache.ped)
    return model == `mp_m_freemode_01` or model == `mp_f_freemode_01`
end

local function copyList(list)
    local out = {}
    for i, item in ipairs(list or {}) do out[i] = { name = item.name, opacity = item.opacity } end
    return out
end

---Starts the tattoo list from a saved look's (illenium-appearance's format)
function look.loadTattoos(saved)
    look.tattoos = {}
    for zone, list in pairs(type(saved) == 'table' and saved or {}) do
        local out = {}
        for _, tattoo in ipairs(type(list) == 'table' and list or {}) do
            if type(tattoo) == 'table' and tattoo.name then
                out[#out + 1] = { name = tattoo.name, opacity = tonumber(tattoo.opacity) or 1.0 }
            end
        end
        look.tattoos[zone] = out
    end
end

-- Darker tattoos are the same decoration drawn more times (illenium-appearance does the same: opacity * 10)
local function drawTattoos()
    local ped, sex = cache.ped, look.sex()
    ClearPedDecorations(ped)

    for _, list in pairs(look.tattoos) do
        for _, item in ipairs(list) do
            local entry = catalog.get(item.name)
            local hash = entry and catalog.hashFor(entry, sex)
            if hash then
                for _ = 1, math.max(1, math.floor(item.opacity * 10 + 0.5)) do
                    AddPedDecorationFromHashes(ped, joaat(entry.collection), joaat(hash))
                end
            end
        end
    end
end

---The tattoos of a zone this ped can get, for the shop page: { name, label }
function look.tattooItems(zone)
    local items = {}
    for i, entry in ipairs(catalog.list(zone, look.sex())) do items[i] = { name = entry.name, label = entry.label } end
    return items
end

---The value of one category on the ped now
function look.get(category)
    local ped, slot = cache.ped, category.slot

    if category.kind == 'tattoo' then return copyList(look.tattoos[category.zone]) end

    if category.kind == 'component' then
        return { drawable = GetPedDrawableVariation(ped, slot), texture = GetPedTextureVariation(ped, slot) }
    elseif category.kind == 'prop' then
        local drawable = GetPedPropIndex(ped, slot)
        return { drawable = drawable, texture = drawable == -1 and -1 or GetPedPropTextureIndex(ped, slot) }
    elseif category.kind == 'hair' then
        return {
            style = GetPedDrawableVariation(ped, 2),
            texture = GetPedTextureVariation(ped, 2),
            color = GetPedHairColor(ped),
            highlight = GetPedHairHighlightColor(ped),
        }
    end

    local _, style, _, color, secondColor, opacity = GetPedHeadOverlayData(ped, slot)
    if style == 255 then style, opacity = 0, 0.0 end
    return { style = style, opacity = math.floor(opacity * 100 + 0.5) / 100, color = color, secondColor = secondColor }
end

---Puts one category's value on the ped
function look.set(category, value)
    local ped, slot = cache.ped, category.slot

    if category.kind == 'tattoo' then
        look.tattoos[category.zone] = copyList(value)
        drawTattoos()
        return
    end

    if category.kind == 'component' then
        SetPedComponentVariation(ped, slot, value.drawable, value.texture, 0)
    elseif category.kind == 'prop' then
        if value.drawable < 0 then
            ClearPedProp(ped, slot)
        else
            SetPedPropIndex(ped, slot, value.drawable, value.texture, true)
        end
    elseif category.kind == 'hair' then
        SetPedComponentVariation(ped, 2, value.style, value.texture, 0)
        SetPedHairColor(ped, value.color, value.highlight)
    else
        SetPedHeadOverlay(ped, slot, value.style, value.opacity)
        SetPedHeadOverlayColor(ped, slot, COLOR_TYPE[category.colors] or 0, value.color, value.secondColor)
    end
end

---How many styles a category has on this ped
function look.count(category)
    local ped, slot = cache.ped, category.slot
    if category.kind == 'component' then return GetNumberOfPedDrawableVariations(ped, slot) end
    if category.kind == 'prop' then return GetNumberOfPedPropDrawableVariations(ped, slot) end
    if category.kind == 'hair' then return GetNumberOfPedDrawableVariations(ped, 2) end
    if category.kind == 'tattoo' then return #catalog.list(category.zone, look.sex()) end
    return GetPedHeadOverlayNum(slot)
end

---How many colors (textures) one style has
function look.textures(category, drawable)
    local ped, slot = cache.ped, category.slot
    if category.kind == 'component' then return GetNumberOfPedTextureVariations(ped, slot, drawable) end
    if category.kind == 'prop' then
        if drawable < 0 then return 0 end
        return GetNumberOfPedPropTextureVariations(ped, slot, drawable)
    end
    if category.kind == 'hair' then return GetNumberOfPedTextureVariations(ped, 2, drawable) end
    return 0
end

local function rgb(r, g, b)
    return ('#%02x%02x%02x'):format(r, g, b)
end

function look.palettes()
    local hair, makeup = {}, {}
    for i = 0, GetNumHairColors() - 1 do hair[#hair + 1] = rgb(GetPedHairRgbColor(i)) end
    for i = 0, GetNumMakeupColors() - 1 do makeup[#makeup + 1] = rgb(GetMakeupRgbColor(i)) end
    return { hair = hair, makeup = makeup }
end

local function sameTattoos(a, b)
    if #a ~= #b then return false end

    local opacity = {}
    for _, item in ipairs(b) do opacity[item.name] = item.opacity end
    for _, item in ipairs(a) do
        if opacity[item.name] ~= item.opacity then return false end
    end

    return true
end

local function same(a, b)
    if a.opacity == 0 and b.opacity == 0 then return true end
    for k, v in pairs(a) do
        if b[k] ~= v then return false end
    end
    return true
end

---What the shop sends the server: only the categories changed since the shop opened. A uniform (police, prison)
---worn over the saved look must not end up in it because the player bought a hat.
---@param baseline table<string, table> look.get of every category when the shop opened (or after the last purchase)
function look.wanted(categories, baseline)
    local wanted = { components = {}, props = {}, overlays = {}, tattoos = {} }

    for _, category in ipairs(categories) do
        local value = look.get(category)

        if category.kind == 'tattoo' then
            if not sameTattoos(value, baseline[category.id]) then wanted.tattoos[category.zone] = value end
        elseif not same(value, baseline[category.id]) then
            if category.kind == 'component' then
                wanted.components[tostring(category.slot)] = value
            elseif category.kind == 'prop' then
                wanted.props[tostring(category.slot)] = value
            elseif category.kind == 'hair' then
                wanted.hair = value
            else
                wanted.overlays[OVERLAY_NAMES[category.slot]] = value
            end
        end
    end

    return wanted
end

local appearance = exports['illenium-appearance']

function look.snapshot()
    return appearance:getPedAppearance(cache.ped)
end

function look.restore(skin)
    if skin then appearance:setPedAppearance(cache.ped, skin) end
end

return look
