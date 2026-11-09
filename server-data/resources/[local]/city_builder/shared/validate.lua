-- Checks what the editor sends before the server stores it. Plain Lua (tested in tests/city_builder/).
local validate = {}

local MAP_MIN, MAP_MAX = -8500.0, 8500.0
local Z_MIN, Z_MAX = -500.0, 3000.0
local INT32_MIN, INT32_MAX = -2147483648, 4294967295

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function integer(value)
    return finite(value) and value == math.floor(value)
end

---@param angle number degrees
---@return number angle in (-180, 180]
function validate.angle(angle)
    angle = angle % 360.0
    if angle > 180.0 then angle = angle - 360.0 end

    return angle
end

---A model name as GTA and stream files spell them: letters, digits, _ and -.
---@return string?
function validate.model(name)
    if type(name) ~= 'string' or #name < 1 or #name > 64 then return end
    if not name:match('^[%w_%-]+$') then return end

    return name:lower()
end

---@return boolean
function validate.inMap(x, y, z)
    return finite(x) and finite(y) and finite(z)
        and x >= MAP_MIN and x <= MAP_MAX and y >= MAP_MIN and y <= MAP_MAX and z >= Z_MIN and z <= Z_MAX
end

---A prop to create or update.
---@param data unknown
---@return table? prop { model, x, y, z, rx, ry, rz, collision, group }
---@return string? reason
function validate.prop(data)
    if type(data) ~= 'table' then return nil, 'not_table' end

    local model = validate.model(data.model)
    if not model then return nil, 'model' end
    if not validate.inMap(data.x, data.y, data.z) then return nil, 'coords' end
    if not (finite(data.rx) and finite(data.ry) and finite(data.rz)) then return nil, 'rotation' end

    local group = data.group
    if group ~= nil and not (integer(group) and group > 0) then return nil, 'group' end

    return {
        model = model,
        x = data.x, y = data.y, z = data.z,
        rx = validate.angle(data.rx), ry = validate.angle(data.ry), rz = validate.angle(data.rz),
        collision = data.collision ~= false,
        group = group,
    }
end

---A map prop to hide: its model hash and where it stands.
---@return table? hide { model, label, x, y, z }
---@return string? reason
function validate.hide(data)
    if type(data) ~= 'table' then return nil, 'not_table' end
    if not integer(data.model) or data.model < INT32_MIN or data.model > INT32_MAX then return nil, 'model' end
    if not validate.inMap(data.x, data.y, data.z) then return nil, 'coords' end

    -- Unsigned hashes (as joaat gives them) are stored signed, as GetEntityModel returns them
    local model = data.model
    if model > 2147483647 then model = model - 4294967296 end

    local label = validate.model(data.label) or ('0x%08X'):format(model % 4294967296)

    return { model = model, label = label, x = data.x, y = data.y, z = data.z }
end

---@return string?
function validate.groupName(name)
    if type(name) ~= 'string' then return end

    name = name:gsub('[%c<>]', ''):match('^%s*(.-)%s*$')
    if #name < 1 or #name > 40 then return end

    return name
end

---A group move: an offset in metres, each axis up to max.
---@return number? x
---@return number? y
---@return number? z
function validate.offset(data, max)
    if type(data) ~= 'table' then return end

    local x, y, z = data.x, data.y, data.z
    if not (finite(x) and finite(y) and finite(z)) then return end
    if math.abs(x) > max or math.abs(y) > max or math.abs(z) > max then return end
    if x == 0 and y == 0 and z == 0 then return end

    return x, y, z
end

return validate
