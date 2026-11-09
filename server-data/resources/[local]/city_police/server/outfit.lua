-- Checks a list of clothes from a client (illenium-appearance's format) before it is saved: known slots only (others
-- are left out), whole numbers in range (numbers that arrive as text or 55.0 are accepted), no slot twice. Used for
-- uniforms and for an officer's own clothes kept while in uniform. A refusal says why, for the server log.

local outfit = {}

local COMPONENTS = { [0] = true, true, true, true, true, true, true, true, true, true, true, true } -- 0..11
local PROPS = { [0] = true, [1] = true, [2] = true, [6] = true, [7] = true }
local MAX_DRAWABLE = 4095
local MAX_TEXTURE = 255
local MAX_ENTRIES = 32

---@param value unknown
---@param min integer
---@param max integer
---@return integer?
local function int(value, min, max)
    value = tonumber(value)
    if not value or value ~= math.floor(value) then return end

    value = math.floor(value)
    if value < min or value > max then return end

    return value
end

---@param list unknown
---@param idKey string 'component_id' | 'prop_id'
---@param ids table<integer, true>
---@return table[]? clean, string? why
local function clean(list, idKey, ids)
    if type(list) ~= 'table' then return nil, ('%s: not a list'):format(idKey) end

    local out, seen, count = {}, {}, 0

    for _, entry in pairs(list) do
        count = count + 1
        if count > MAX_ENTRIES then return nil, ('%s: too many'):format(idKey) end
        if type(entry) ~= 'table' then return nil, ('%s: entry is %s'):format(idKey, type(entry)) end

        local id = int(entry[idKey], 0, 11)

        if id and ids[id] and not seen[id] then
            local drawable = int(entry.drawable, -1, MAX_DRAWABLE)
            local texture = int(entry.texture, -1, MAX_TEXTURE)

            if not drawable or not texture then
                return nil, ('%s %d: drawable %s texture %s'):format(idKey, id, tostring(entry.drawable), tostring(entry.texture))
            end

            seen[id] = true
            out[#out + 1] = { [idKey] = id, drawable = drawable, texture = texture }
        end
    end

    table.sort(out, function(a, b) return a[idKey] < b[idKey] end)

    return out
end

---@param components unknown
---@param props unknown
---@return table[]? components, table[]|string props, or nil and why
function outfit.check(components, props)
    local cleanComponents, why = clean(components, 'component_id', COMPONENTS)
    if not cleanComponents then return nil, why end
    if #cleanComponents == 0 then return nil, 'no clothes' end

    local cleanProps, whyProps = clean(props or {}, 'prop_id', PROPS)
    if not cleanProps then return nil, whyProps end

    return cleanComponents, cleanProps
end

-- A uniform never carries the face (0) or the hair (2) of whoever made it
local NOT_UNIFORM = { [0] = true, [2] = true }

---@param components table[] checked components
---@return table[]
function outfit.uniformOnly(components)
    local out = {}

    for _, entry in ipairs(components) do
        if not NOT_UNIFORM[entry.component_id] then out[#out + 1] = entry end
    end

    return out
end

---@param value unknown
---@return 'male' | 'female' | nil
function outfit.sex(value)
    return (value == 'male' or value == 'female') and value or nil
end

return outfit
