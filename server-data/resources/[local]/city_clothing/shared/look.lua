-- What a shop may change on a saved look, and what it costs. Pure Lua (tests/city_clothing): the server runs it on the
-- look saved in playerskins (illenium-appearance's format) and what the shop asked for, never on prices from the client.
local look = {}

-- illenium's names for the head overlays, by game index
look.OVERLAYS = {
    [1] = { name = 'beard', max = 28 },
    [2] = { name = 'eyebrows', max = 33 },
    [4] = { name = 'makeUp', max = 74 },
    [5] = { name = 'blush', max = 6 },
    [8] = { name = 'lipstick', max = 9 },
    [10] = { name = 'chestHair', max = 16 },
}

look.MODELS = { m = 'mp_m_freemode_01', f = 'mp_f_freemode_01' }

local MAX_DRAWABLE = 2000 -- addon packs go far past the base game's counts
local MAX_TEXTURE = 255
local MAX_COLOR = 63

-- Never part of an outfit: the face (0) and the hair (2) belong to the character, not the clothes
local NOT_CLOTHES = { [0] = true, [2] = true }

local function isNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function int(value, min, max)
    if not isNumber(value) or value ~= math.floor(value) or value < min or value > max then return nil end
    -- Page numbers can arrive as floats (5.0); saved JSON should hold 5
    return math.tointeger and math.tointeger(value) or value
end

local function float(value, min, max)
    if not isNumber(value) or value < min or value > max then return nil end
    return math.floor(value * 100 + 0.5) / 100
end

local function copy(value)
    if type(value) ~= 'table' then return value end

    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
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

---'m' or 'f' from a saved look's model, nil for anything else (a ped model can't use the shop)
function look.sexOf(skin)
    if type(skin) ~= 'table' then return nil end
    if skin.model == look.MODELS.m then return 'm' end
    if skin.model == look.MODELS.f then return 'f' end
end

---The entry for a component or prop id in illenium's list, added if it's missing
local function entry(list, key, id)
    for i = 1, #list do
        if list[i][key] == id then return list[i] end
    end

    local new = { [key] = id, drawable = key == 'prop_id' and -1 or 0, texture = key == 'prop_id' and -1 or 0 }
    list[#list + 1] = new
    return new
end

local readers = {}

function readers.component(category, wanted)
    local value = wanted.components and wanted.components[tostring(category.slot)]
    if value == nil then return nil end
    if type(value) ~= 'table' then return false end

    local drawable = int(value.drawable, 0, MAX_DRAWABLE)
    local texture = int(value.texture, 0, MAX_TEXTURE)
    if not drawable or not texture then return false end

    return { drawable = drawable, texture = texture }
end

function readers.prop(category, wanted)
    local value = wanted.props and wanted.props[tostring(category.slot)]
    if value == nil then return nil end
    if type(value) ~= 'table' then return false end

    local drawable = int(value.drawable, -1, MAX_DRAWABLE)
    if not drawable then return false end
    if drawable == -1 then return { drawable = -1, texture = -1 } end

    local texture = int(value.texture, 0, MAX_TEXTURE)
    if not texture then return false end

    return { drawable = drawable, texture = texture }
end

function readers.hair(_, wanted)
    local value = wanted.hair
    if value == nil then return nil end
    if type(value) ~= 'table' then return false end

    local style = int(value.style, 0, MAX_DRAWABLE)
    local texture = int(value.texture, 0, MAX_TEXTURE)
    local color = int(value.color, 0, MAX_COLOR)
    local highlight = int(value.highlight, 0, MAX_COLOR)
    if not style or not texture or not color or not highlight then return false end

    return { style = style, texture = texture, color = color, highlight = highlight }
end

function readers.overlay(category, wanted)
    local def = look.OVERLAYS[category.slot]
    local value = def and wanted.overlays and wanted.overlays[def.name]
    if value == nil then return nil end
    if type(value) ~= 'table' then return false end

    local style = int(value.style, 0, def.max)
    local opacity = float(value.opacity, 0, 1)
    local color = int(value.color or 0, 0, MAX_COLOR)
    local secondColor = int(value.secondColor or 0, 0, MAX_COLOR)
    if not style or not opacity or not color or not secondColor then return false end

    return { style = style, opacity = opacity, color = color, secondColor = secondColor }
end

---What the saved look has now for a category, in the same shape the readers return
local function current(skin, category)
    local kind, slot = category.kind, category.slot

    if kind == 'component' then
        local e = entry(skin.components, 'component_id', slot)
        return { drawable = e.drawable, texture = e.texture }
    elseif kind == 'prop' then
        local e = entry(skin.props, 'prop_id', slot)
        if e.drawable == -1 then return { drawable = -1, texture = -1 } end
        return { drawable = e.drawable, texture = e.texture }
    elseif kind == 'hair' then
        local h = skin.hair or {}
        return { style = h.style or 0, texture = h.texture or 0, color = h.color or 0, highlight = h.highlight or 0 }
    else
        local o = skin.headOverlays[look.OVERLAYS[slot].name] or {}
        return { style = o.style or 0, opacity = o.opacity or 0, color = o.color or 0, secondColor = o.secondColor or 0 }
    end
end

local function same(a, b)
    -- An overlay that isn't drawn is the same whatever style number it keeps
    if a.opacity == 0 and b.opacity == 0 then return true end

    for k, v in pairs(a) do
        if b[k] ~= v then return false end
    end
    return true
end

local function write(skin, category, value)
    local kind, slot = category.kind, category.slot

    if kind == 'component' then
        local e = entry(skin.components, 'component_id', slot)
        e.drawable, e.texture = value.drawable, value.texture
    elseif kind == 'prop' then
        local e = entry(skin.props, 'prop_id', slot)
        e.drawable, e.texture = value.drawable, value.texture
    elseif kind == 'hair' then
        skin.hair = value
        local e = entry(skin.components, 'component_id', 2)
        e.drawable, e.texture = value.style, value.texture
    else
        skin.headOverlays[look.OVERLAYS[slot].name] = value
    end
end

---Builds the new saved look from what the shop asked for and prices the categories that changed.
---@param skin table the look saved in playerskins
---@param wanted table { components, props, hair, overlays } from the shop
---@param categories table[] the categories this shop sells: { id, kind, slot, sex? }
---@param options { prices: table<string, integer>, blocked: table? }
---@return table? newSkin
---@return table[]|string changes { id, price } or why it was refused
---@return integer? total
function look.buy(skin, wanted, categories, options)
    local sex = look.sexOf(skin)
    if not sex then return nil, 'model' end
    if type(wanted) ~= 'table' then return nil, 'look' end

    local new = copy(skin)
    new.components = type(new.components) == 'table' and new.components or {}
    new.props = type(new.props) == 'table' and new.props or {}
    new.headOverlays = type(new.headOverlays) == 'table' and new.headOverlays or {}

    local blockList = options.blocked and options.blocked[sex] or {}
    local changes, total = {}, 0

    for i = 1, #categories do
        local category = categories[i]
        local value = readers[category.kind](category, wanted)

        if value == false then return nil, category.id end

        if value and (not category.sex or category.sex == sex) and not same(value, current(new, category)) then
            local blockKey = category.kind == 'prop' and 'p' .. category.slot or category.slot
            local drawable = value.drawable or value.style
            if blocked(blockList[blockKey], drawable) then return nil, category.id .. ' blocked' end

            write(new, category, value)

            local price = options.prices[category.id] or 0
            changes[#changes + 1] = { id = category.id, price = price }
            total = total + price
        end
    end

    return new, changes, total
end

---Builds the new saved tattoos from what the shop asked for. Each zone sent replaces that zone's list; a new tattoo
---costs options.prices.tattoo, removing one or changing its intensity is free.
---@param skin table the look saved in playerskins
---@param wanted table? { [zone] = { { name, opacity }, ... } } from the shop
---@param categories table[] the tattoo categories this shop sells: { id, zone }
---@param catalog table shared/tattoos.lua (get, hashFor)
---@param options { prices: table<string, integer>, maxPerZone: integer }
---@return table? newSkin
---@return table[]|string changes { id, tattoo, price, removed? } or why it was refused
---@return integer? total
function look.buyTattoos(skin, wanted, categories, catalog, options)
    local sex = look.sexOf(skin)
    if not sex then return nil, 'model' end
    if wanted ~= nil and type(wanted) ~= 'table' then return nil, 'tattoos' end
    wanted = wanted or {}

    local new = copy(skin)
    new.tattoos = type(new.tattoos) == 'table' and new.tattoos or {}

    local price = options.prices.tattoo or 0
    local changes, total = {}, 0

    for _, category in ipairs(categories) do
        local zone = category.zone
        local list = wanted[zone]

        if list ~= nil then
            if type(list) ~= 'table' or #list > options.maxPerZone then return nil, category.id end

            local owned = {}
            for _, tattoo in ipairs(type(new.tattoos[zone]) == 'table' and new.tattoos[zone] or {}) do
                if type(tattoo) == 'table' and tattoo.name then owned[tattoo.name] = tattoo end
            end

            local seen, out = {}, {}
            for _, item in ipairs(list) do
                if type(item) ~= 'table' or type(item.name) ~= 'string' or seen[item.name] then return nil, category.id end

                local opacity = float(item.opacity, 0.1, 1)
                if not opacity then return nil, category.id end
                opacity = math.floor(opacity * 10 + 0.5) / 10

                local had = owned[item.name]
                local entry = had or catalog.get(item.name)
                -- A tattoo already owned stays even if the catalog changed; a new one must exist for this sex and zone
                if not had and (not entry or entry.zone ~= zone or not catalog.hashFor(entry, sex)) then
                    return nil, category.id
                end

                seen[item.name] = true
                out[#out + 1] = {
                    name = entry.name, label = entry.label, collection = entry.collection, zone = zone,
                    hashMale = entry.hashMale, hashFemale = entry.hashFemale, opacity = opacity,
                }

                if not had then
                    changes[#changes + 1] = { id = category.id, tattoo = item.name, price = price }
                    total = total + price
                elseif had.opacity ~= opacity then
                    changes[#changes + 1] = { id = category.id, tattoo = item.name, price = 0 }
                end
            end

            for name in pairs(owned) do
                if not seen[name] then changes[#changes + 1] = { id = category.id, tattoo = name, price = 0, removed = true } end
            end

            new.tattoos[zone] = out
        end
    end

    return new, changes, total
end

---The clothes of a saved look as an illenium outfit (components and props lists), without face and hair
function look.outfitOf(skin)
    local components, props = {}, {}

    for _, c in ipairs(skin.components or {}) do
        if not NOT_CLOTHES[c.component_id] then
            components[#components + 1] = { component_id = c.component_id, drawable = c.drawable, texture = c.texture }
        end
    end

    for _, p in ipairs(skin.props or {}) do
        props[#props + 1] = { prop_id = p.prop_id, drawable = p.drawable, texture = p.texture }
    end

    return components, props
end

---Puts a saved outfit's clothes on a saved look; face and hair stay. Rows come from the database, still checked.
---@return table? newSkin
function look.wear(skin, components, props)
    if not look.sexOf(skin) or type(components) ~= 'table' or type(props) ~= 'table' then return nil end

    local new = copy(skin)
    new.components = type(new.components) == 'table' and new.components or {}
    new.props = type(new.props) == 'table' and new.props or {}

    for _, c in ipairs(components) do
        local id = type(c) == 'table' and int(c.component_id, 0, 11)
        if id and not NOT_CLOTHES[id] then
            local drawable, texture = int(c.drawable, 0, MAX_DRAWABLE), int(c.texture, 0, MAX_TEXTURE)
            if not drawable or not texture then return nil end

            local e = entry(new.components, 'component_id', id)
            e.drawable, e.texture = drawable, texture
        end
    end

    for _, p in ipairs(props) do
        local id = type(p) == 'table' and int(p.prop_id, 0, 13)
        if id then
            local drawable = int(p.drawable, -1, MAX_DRAWABLE)
            local texture = drawable == -1 and -1 or int(p.texture, 0, MAX_TEXTURE)
            if not drawable or not texture then return nil end

            local e = entry(new.props, 'prop_id', id)
            e.drawable, e.texture = drawable, texture
        end
    end

    return new
end

return look
