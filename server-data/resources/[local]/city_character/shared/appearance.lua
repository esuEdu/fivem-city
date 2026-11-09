-- What a character's look is made of, and the server-side check that turns the creator's draft into the
-- illenium-appearance format saved in playerskins. Plain Lua so tests/city_character can run it.
local appearance = {}

appearance.MODELS = { m = 'mp_m_freemode_01', f = 'mp_f_freemode_01' }

-- Game order (SetPedFaceFeature index = position - 1); names are illenium's
appearance.FEATURES = {
    'noseWidth', 'nosePeakHigh', 'nosePeakSize', 'noseBoneHigh', 'nosePeakLowering', 'noseBoneTwist',
    'eyeBrownHigh', 'eyeBrownForward', 'cheeksBoneHigh', 'cheeksBoneWidth', 'cheeksWidth', 'eyesOpening',
    'lipsThickness', 'jawBoneWidth', 'jawBoneBackSize', 'chinBoneLowering', 'chinBoneLenght', 'chinBoneSize',
    'chinHole', 'neckThickness',
}

-- Game order (SetPedHeadOverlay index = position - 1). max = last style, colorType 1 = hair palette, 2 = makeup palette
appearance.OVERLAYS = {
    { name = 'blemishes', max = 23 },
    { name = 'beard', max = 28, colorType = 1 },
    { name = 'eyebrows', max = 33, colorType = 1 },
    { name = 'ageing', max = 14 },
    { name = 'makeUp', max = 74, colorType = 2 },
    { name = 'blush', max = 6, colorType = 2 },
    { name = 'complexion', max = 11 },
    { name = 'sunDamage', max = 10 },
    { name = 'lipstick', max = 9, colorType = 2 },
    { name = 'moleAndFreckles', max = 17 },
    { name = 'chestHair', max = 16, colorType = 1 },
    { name = 'bodyBlemishes', max = 11 },
}

appearance.COMPONENTS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
appearance.PROPS = { 0, 1, 2, 6, 7 }

-- Head blend faces: 0-20 men, 21-41 women, 42-45 the special faces. Pictures are the game's char_creator_portraits
appearance.PARENTS = {
    { id = 21, name = 'Hannah', pic = 'female_0' }, { id = 22, name = 'Audrey', pic = 'female_1' },
    { id = 23, name = 'Jasmine', pic = 'female_2' }, { id = 24, name = 'Giselle', pic = 'female_3' },
    { id = 25, name = 'Amelia', pic = 'female_4' }, { id = 26, name = 'Isabella', pic = 'female_5' },
    { id = 27, name = 'Zoe', pic = 'female_6' }, { id = 28, name = 'Ava', pic = 'female_7' },
    { id = 29, name = 'Camila', pic = 'female_8' }, { id = 30, name = 'Violet', pic = 'female_9' },
    { id = 31, name = 'Sophia', pic = 'female_10' }, { id = 32, name = 'Evelyn', pic = 'female_11' },
    { id = 33, name = 'Nicole', pic = 'female_12' }, { id = 34, name = 'Ashley', pic = 'female_13' },
    { id = 35, name = 'Grace', pic = 'female_14' }, { id = 36, name = 'Brianna', pic = 'female_15' },
    { id = 37, name = 'Natalie', pic = 'female_16' }, { id = 38, name = 'Olivia', pic = 'female_17' },
    { id = 39, name = 'Elizabeth', pic = 'female_18' }, { id = 40, name = 'Charlotte', pic = 'female_19' },
    { id = 41, name = 'Emma', pic = 'female_20' }, { id = 45, name = 'Misty', pic = 'special_female_0' },
    { id = 0, name = 'Benjamin', pic = 'male_0' }, { id = 1, name = 'Daniel', pic = 'male_1' },
    { id = 2, name = 'Joshua', pic = 'male_2' }, { id = 3, name = 'Noah', pic = 'male_3' },
    { id = 4, name = 'Andrew', pic = 'male_4' }, { id = 5, name = 'Juan', pic = 'male_5' },
    { id = 6, name = 'Alex', pic = 'male_6' }, { id = 7, name = 'Isaac', pic = 'male_7' },
    { id = 8, name = 'Evan', pic = 'male_8' }, { id = 9, name = 'Ethan', pic = 'male_9' },
    { id = 10, name = 'Vincent', pic = 'male_10' }, { id = 11, name = 'Angel', pic = 'male_11' },
    { id = 12, name = 'Diego', pic = 'male_12' }, { id = 13, name = 'Adrian', pic = 'male_13' },
    { id = 14, name = 'Gabriel', pic = 'male_14' }, { id = 15, name = 'Michael', pic = 'male_15' },
    { id = 16, name = 'Santiago', pic = 'male_16' }, { id = 17, name = 'Kevin', pic = 'male_17' },
    { id = 18, name = 'Louis', pic = 'male_18' }, { id = 19, name = 'Samuel', pic = 'male_19' },
    { id = 20, name = 'Anthony', pic = 'male_20' }, { id = 42, name = 'Claude', pic = 'special_male_0' },
    { id = 43, name = 'Niko', pic = 'special_male_1' }, { id = 44, name = 'John', pic = 'special_male_2' },
}

local MAX_PARENT = 45
local MAX_DRAWABLE = 2000 -- addon clothing packs go far past the base game's counts
local MAX_TEXTURE = 255
local MAX_COLOR = 63

local function isNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function int(value, min, max)
    if not isNumber(value) or value ~= math.floor(value) or value < min or value > max then return nil end
    return value
end

-- Floats are kept to two decimals so a crafted payload can't bloat the saved JSON
local function float(value, min, max)
    if not isNumber(value) or value < min or value > max then return nil end
    return math.floor(value * 100 + 0.5) / 100
end

local function blocked(list, drawable)
    if not list then return false end

    for i = 1, #list do
        local entry = list[i]
        if type(entry) == 'number' then
            if entry == drawable then return true end
        elseif drawable >= entry[1] and drawable <= entry[2] then
            return true
        end
    end

    return false
end

local function piece(entry, minDrawable)
    if type(entry) ~= 'table' then return nil end

    local drawable = int(entry.drawable, minDrawable, MAX_DRAWABLE)
    local texture = int(entry.texture, minDrawable, MAX_TEXTURE)
    if not drawable or not texture then return nil end

    return drawable, texture
end

---Checks a creator draft and builds the appearance illenium-appearance saves and loads.
---@param draft table what the creator sent: sex, heritage, features, overlays, hair, eyeColor, components, props
---@param options { blocked: table?, eyeColors: integer }
---@return table? appearance
---@return string? reason why the draft was refused
function appearance.build(draft, options)
    if type(draft) ~= 'table' then return nil, 'draft' end

    local sex = draft.sex
    local model = appearance.MODELS[sex]
    if not model then return nil, 'sex' end

    local blockList = options.blocked and options.blocked[sex] or {}

    local heritage = draft.heritage
    if type(heritage) ~= 'table' then return nil, 'heritage' end

    local mother = int(heritage.mother, 0, MAX_PARENT)
    local father = int(heritage.father, 0, MAX_PARENT)
    local shapeMix = float(heritage.shapeMix, 0, 1)
    local skinMix = float(heritage.skinMix, 0, 1)
    -- Skin can come from other faces than the shape, so any skin tone fits any face
    local skinMother = heritage.skinMother == nil and mother or int(heritage.skinMother, 0, MAX_PARENT)
    local skinFather = heritage.skinFather == nil and father or int(heritage.skinFather, 0, MAX_PARENT)
    if not mother or not father or not shapeMix or not skinMix or not skinMother or not skinFather then
        return nil, 'heritage'
    end

    local features = {}
    local draftFeatures = type(draft.features) == 'table' and draft.features or {}
    for i = 1, #appearance.FEATURES do
        local name = appearance.FEATURES[i]
        local value = draftFeatures[name] == nil and 0 or float(draftFeatures[name], -1, 1)
        if not value then return nil, ('feature %s'):format(name) end
        features[name] = value
    end

    local overlays = {}
    local draftOverlays = type(draft.overlays) == 'table' and draft.overlays or {}
    for i = 1, #appearance.OVERLAYS do
        local def = appearance.OVERLAYS[i]
        local entry = draftOverlays[def.name]

        if entry == nil then
            overlays[def.name] = { style = 0, opacity = 0, color = 0, secondColor = 0 }
        else
            if type(entry) ~= 'table' then return nil, ('overlay %s'):format(def.name) end

            local style = int(entry.style, 0, def.max)
            local opacity = float(entry.opacity, 0, 1)
            local color = int(entry.color or 0, 0, MAX_COLOR)
            local secondColor = int(entry.secondColor or 0, 0, MAX_COLOR)
            if not style or not opacity or not color or not secondColor then
                return nil, ('overlay %s'):format(def.name)
            end

            overlays[def.name] = { style = style, opacity = opacity, color = color, secondColor = secondColor }
        end
    end

    local hair = draft.hair
    if type(hair) ~= 'table' then return nil, 'hair' end

    local hairStyle = int(hair.style, 0, MAX_DRAWABLE)
    local hairTexture = int(hair.texture, 0, MAX_TEXTURE)
    local hairColor = int(hair.color, 0, MAX_COLOR)
    local highlight = int(hair.highlight, 0, MAX_COLOR)
    if not hairStyle or not hairTexture or not hairColor or not highlight then return nil, 'hair' end
    if blocked(blockList[2], hairStyle) then return nil, 'hair blocked' end

    local eyeColor = int(draft.eyeColor, 0, options.eyeColors - 1)
    if not eyeColor then return nil, 'eyes' end

    local draftComponents = type(draft.components) == 'table' and draft.components or {}
    local components = {}
    for i = 1, #appearance.COMPONENTS do
        local id = appearance.COMPONENTS[i]
        local drawable, texture = 0, 0

        if id == 2 then
            drawable, texture = hairStyle, hairTexture
        elseif id ~= 0 then
            local entry = draftComponents[tostring(id)]
            if entry ~= nil then
                drawable, texture = piece(entry, 0)
                if not drawable then return nil, ('component %d'):format(id) end
                if blocked(blockList[id], drawable) then return nil, ('component %d blocked'):format(id) end
            end
        end

        components[i] = { component_id = id, drawable = drawable, texture = texture }
    end

    local draftProps = type(draft.props) == 'table' and draft.props or {}
    local props = {}
    for i = 1, #appearance.PROPS do
        local id = appearance.PROPS[i]
        local drawable, texture = -1, -1
        local entry = draftProps[tostring(id)]

        if entry ~= nil then
            drawable, texture = piece(entry, -1)
            if not drawable then return nil, ('prop %d'):format(id) end
            if drawable == -1 then
                texture = -1
            elseif blocked(blockList['p' .. id], drawable) then
                return nil, ('prop %d blocked'):format(id)
            elseif texture < 0 then
                return nil, ('prop %d'):format(id)
            end
        end

        props[i] = { prop_id = id, drawable = drawable, texture = texture }
    end

    return {
        model = model,
        headBlend = {
            shapeFirst = mother, shapeSecond = father, shapeThird = 0,
            skinFirst = skinMother, skinSecond = skinFather, skinThird = 0,
            shapeMix = shapeMix, skinMix = skinMix, thirdMix = 0,
        },
        faceFeatures = features,
        headOverlays = overlays,
        components = components,
        props = props,
        hair = { style = hairStyle, texture = hairTexture, color = hairColor, highlight = highlight },
        eyeColor = eyeColor,
        tattoos = {},
    }
end

return appearance
