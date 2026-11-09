-- Clothes from a client (illenium-appearance's format), for uniforms and for an officer's own clothes kept while in
-- uniform. Only clothing slots count, so a uniform never touches the face, hair, glasses, ears, watch or bracelets:
-- components 1 (mask), 3 (arms) and 4 to 11, and prop 0 (hat). Other slots and bad entries are left out (and named,
-- for the server log) instead of refusing the whole outfit.

local outfit = {}

outfit.COMPONENTS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
outfit.PROPS = { 0 }

local COMPONENT_SET, PROP_SET = {}, {}
for _, id in ipairs(outfit.COMPONENTS) do COMPONENT_SET[id] = true end
for _, id in ipairs(outfit.PROPS) do PROP_SET[id] = true end

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
---@param allowed table<integer, true>
---@param skipped string[] filled with what was left out
---@return table[]
local function clean(list, idKey, allowed, skipped)
    local out, seen, count = {}, {}, 0
    if type(list) ~= 'table' then return out end

    for _, entry in pairs(list) do
        count = count + 1
        if count > MAX_ENTRIES then break end

        local id = type(entry) == 'table' and int(entry[idKey], 0, 11) or nil

        if id and allowed[id] and not seen[id] then
            local drawable = int(entry.drawable, -1, MAX_DRAWABLE)
            local texture = int(entry.texture, -1, MAX_TEXTURE)

            if drawable and texture then
                seen[id] = true
                out[#out + 1] = { [idKey] = id, drawable = drawable, texture = texture }
            else
                skipped[#skipped + 1] = ('%s %d (%s/%s)'):format(idKey, id, tostring(entry.drawable), tostring(entry.texture))
            end
        end
    end

    table.sort(out, function(a, b) return a[idKey] < b[idKey] end)

    return out
end

---@param components unknown
---@param props unknown
---@return table[]? components, table[]? props, string? skipped (nil components: nothing usable at all)
function outfit.check(components, props)
    local skipped = {}
    local cleanComponents = clean(components, 'component_id', COMPONENT_SET, skipped)
    local cleanProps = clean(props, 'prop_id', PROP_SET, skipped)
    local why = #skipped > 0 and table.concat(skipped, ', ') or nil

    if #cleanComponents == 0 then return nil, nil, why or 'no clothes' end

    return cleanComponents, cleanProps, why
end

---@param value unknown
---@return 'male' | 'female' | nil
function outfit.sex(value)
    return (value == 'male' or value == 'female') and value or nil
end

return outfit
