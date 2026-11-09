-- Checks a list of clothes from a client (illenium-appearance's format) before it is saved: known slots, whole numbers
-- in range, no slot twice. Used for uniforms and for an officer's own clothes kept while in uniform.

local outfit = {}

local COMPONENTS = { [0] = true, true, true, true, true, true, true, true, true, true, true, true } -- 0..11
local PROPS = { [0] = true, [1] = true, [2] = true, [6] = true, [7] = true }
local MAX_DRAWABLE = 2000
local MAX_TEXTURE = 100

---@param value unknown
---@param min integer
---@param max integer
---@return integer?
local function int(value, min, max)
    value = math.tointeger(value)
    if not value or value < min or value > max then return end

    return value
end

---@param list unknown
---@param idKey string 'component_id' | 'prop_id'
---@param ids table<integer, true>
---@param minDrawable integer
---@return table[]?
local function clean(list, idKey, ids, minDrawable)
    if type(list) ~= 'table' or #list > 16 then return end

    local out, seen = {}, {}

    for _, entry in ipairs(list) do
        if type(entry) ~= 'table' then return end

        local id = int(entry[idKey], 0, 11)
        local drawable = int(entry.drawable, minDrawable, MAX_DRAWABLE)
        local texture = int(entry.texture, -1, MAX_TEXTURE)
        if not id or not ids[id] or seen[id] or not drawable or not texture then return end

        seen[id] = true
        out[#out + 1] = { [idKey] = id, drawable = drawable, texture = texture }
    end

    return out
end

---@param components unknown
---@param props unknown
---@return table[]? components, table[]? props (both nil when anything is wrong)
function outfit.check(components, props)
    local cleanComponents = clean(components, 'component_id', COMPONENTS, 0)
    local cleanProps = clean(props or {}, 'prop_id', PROPS, -1)
    if not cleanComponents or not cleanProps then return end

    return cleanComponents, cleanProps
end

---@param value unknown
---@return 'male' | 'female' | nil
function outfit.sex(value)
    return (value == 'male' or value == 'female') and value or nil
end

return outfit
