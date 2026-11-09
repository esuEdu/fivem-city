-- Putting a creator draft on the player's ped, piece by piece, and what the game offers for each piece
local appearance = require 'shared.appearance'

local look = {}

local FEATURE_INDEX = {}
for i = 1, #appearance.FEATURES do FEATURE_INDEX[appearance.FEATURES[i]] = i - 1 end

local OVERLAY_INDEX = {}
for i = 1, #appearance.OVERLAYS do OVERLAY_INDEX[appearance.OVERLAYS[i].name] = i end

local illenium = exports['illenium-appearance']

local function sexOf(ped)
    return GetEntityModel(ped) == `mp_f_freemode_01` and 'f' or 'm'
end

function look.setModel(sex)
    local model = joaat(appearance.MODELS[sex])
    if GetEntityModel(cache.ped) == model then return end

    lib.requestModel(model)
    SetPlayerModel(cache.playerId, model)
    SetModelAsNoLongerNeeded(model)

    -- cache.ped only follows the new ped on ox_lib's next tick
    local ped = PlayerPedId()
    cache.ped = ped
    SetPedDefaultComponentVariation(ped)
end

function look.setHeritage(h)
    SetPedHeadBlendData(cache.ped, h.mother, h.father, 0, h.skinMother or h.mother, h.skinFather or h.father, 0,
        h.shapeMix + 0.0, h.skinMix + 0.0, 0.0, false)
end

function look.setFeature(name, value)
    local index = FEATURE_INDEX[name]
    if index then SetPedFaceFeature(cache.ped, index, value + 0.0) end
end

function look.setOverlay(name, entry)
    local position = OVERLAY_INDEX[name]
    if not position then return end

    local def = appearance.OVERLAYS[position]
    local ped = cache.ped
    SetPedHeadOverlay(ped, position - 1, entry.style, entry.opacity + 0.0)

    if def.colorType then
        SetPedHeadOverlayColor(ped, position - 1, def.colorType, entry.color or 0, entry.secondColor or 0)
    end
end

function look.setHair(hair)
    -- illenium's setter also adds the hair fade decoration that goes with the style
    illenium:setPedHair(cache.ped, hair, {})
end

function look.setEyes(color)
    SetPedEyeColor(cache.ped, color)
end

function look.setComponent(id, drawable, texture)
    SetPedComponentVariation(cache.ped, id, drawable, texture, 0)
end

function look.setProp(id, drawable, texture)
    if drawable < 0 then
        ClearPedProp(cache.ped, id)
    else
        SetPedPropIndex(cache.ped, id, drawable, texture, true)
    end
end

function look.applyOutfit(outfit)
    for id, piece in pairs(outfit.components or {}) do look.setComponent(id, piece[1], piece[2]) end
    for id, piece in pairs(outfit.props or {}) do look.setProp(id, piece[1], piece[2]) end
end

---Puts a whole draft on the ped (after a sex change or undo)
function look.apply(draft)
    look.setModel(draft.sex)
    look.setHeritage(draft.heritage)

    for name, value in pairs(draft.features) do look.setFeature(name, value) end
    for name, entry in pairs(draft.overlays) do look.setOverlay(name, entry) end

    look.setHair(draft.hair)
    look.setEyes(draft.eyeColor)

    for id, piece in pairs(draft.components) do look.setComponent(tonumber(id), piece.drawable, piece.texture) end
    for id, piece in pairs(draft.props) do look.setProp(tonumber(id), piece.drawable, piece.texture) end
end

---A plain starting draft for a sex: first parents, smooth face, the first starter look
function look.defaultDraft(sex)
    local female = sex == 'f'
    local outfit = Config.Outfits[sex][1]
    local overlays = {}

    for i = 1, #appearance.OVERLAYS do
        local def = appearance.OVERLAYS[i]
        overlays[def.name] = { style = 0, opacity = 0.0, color = 0, secondColor = 0 }
    end

    overlays.eyebrows = { style = female and 1 or 0, opacity = 1.0, color = 0, secondColor = 0 }

    local components, props = {}, {}
    for i = 1, #Config.Pieces do
        local piece = Config.Pieces[i]
        if piece.kind == 'component' then
            components[tostring(piece.id)] = { drawable = 0, texture = 0 }
        else
            props[tostring(piece.id)] = { drawable = -1, texture = 0 }
        end
    end

    components['1'] = { drawable = 0, texture = 0 }
    components['5'] = { drawable = 0, texture = 0 }
    components['7'] = { drawable = 0, texture = 0 }

    for id, piece in pairs(outfit.components) do
        components[tostring(id)] = { drawable = piece[1], texture = piece[2] }
    end

    local features = {}
    for i = 1, #appearance.FEATURES do features[appearance.FEATURES[i]] = 0.0 end

    return {
        sex = sex,
        heritage = {
            mother = 21,
            father = 0,
            skinMother = 21,
            skinFather = 0,
            shapeMix = female and 0.2 or 0.8,
            skinMix = 0.5,
        },
        features = features,
        overlays = overlays,
        hair = { style = female and 4 or 2, texture = 0, color = 2, highlight = 2 },
        eyeColor = 3,
        components = components,
        props = props,
        outfit = outfit.id,
    }
end

local function rgb(r, g, b)
    return ('#%02x%02x%02x'):format(r, g, b)
end

---Everything the panel needs to draw its choices for the current ped: counts per piece and the color palettes
function look.catalog()
    local ped = cache.ped
    local sex = sexOf(ped)
    local pieces = {}

    for i = 1, #Config.Pieces do
        local piece = Config.Pieces[i]
        local count = piece.kind == 'component'
            and GetNumberOfPedDrawableVariations(ped, piece.id)
            or GetNumberOfPedPropDrawableVariations(ped, piece.id)

        pieces[i] = { kind = piece.kind, id = piece.id, label = piece.label, count = count }
    end

    local overlays = {}
    for i = 1, #appearance.OVERLAYS do
        local def = appearance.OVERLAYS[i]
        local count = GetPedHeadOverlayNum(i - 1)
        overlays[def.name] = { max = math.min(def.max, math.max(count - 1, 0)), colorType = def.colorType }
    end

    local hairColors, makeupColors = {}, {}
    for i = 0, GetNumHairColors() - 1 do hairColors[#hairColors + 1] = rgb(GetPedHairRgbColor(i)) end
    for i = 0, GetNumMakeupColors() - 1 do makeupColors[#makeupColors + 1] = rgb(GetMakeupRgbColor(i)) end

    return {
        sex = sex,
        pieces = pieces,
        hairCount = GetNumberOfPedDrawableVariations(ped, 2),
        overlays = overlays,
        hairColors = hairColors,
        makeupColors = makeupColors,
        outfits = Config.Outfits[sex],
    }
end

---How many textures a piece's drawable has
function look.textures(kind, id, drawable)
    local ped = cache.ped
    if kind == 'hair' then return GetNumberOfPedTextureVariations(ped, 2, drawable) end
    if kind == 'prop' then
        if drawable < 0 then return 0 end
        return GetNumberOfPedPropTextureVariations(ped, id, drawable)
    end

    return GetNumberOfPedTextureVariations(ped, id, drawable)
end

---Shows a saved character's look on the ped (character select). Without one, a plain default ped
function look.preview(model, skin)
    if model and skin then
        lib.requestModel(model)
        SetPlayerModel(cache.playerId, model)
        SetModelAsNoLongerNeeded(model)
        cache.ped = PlayerPedId()
        illenium:setPedAppearance(cache.ped, json.decode(skin))
        return
    end

    local draft = look.defaultDraft('m')
    look.apply(draft)
end

return look
