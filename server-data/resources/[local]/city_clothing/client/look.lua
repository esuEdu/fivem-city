-- Reading and changing the pieces a shop sells on the player's ped (the preview; only the server saves)
local look = {}

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

---The value of one category on the ped now
function look.get(category)
    local ped, slot = cache.ped, category.slot

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
    local wanted = { components = {}, props = {}, overlays = {} }

    for _, category in ipairs(categories) do
        local value = look.get(category)

        if not same(value, baseline[category.id]) then
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
