-- Pick spots: one pick per spot, then it regrows. Which spots are picked is in GlobalState so every client hides them.
local settings = require 'server.config'
local common = require 'server.common'
local spots = require 'shared.spots'

local REGROW_CHECK_MS = 30000

---@type table<string, { x: number, y: number, z: number }[]>
local positions = {}
---@type table<string, integer> spot key -> os.time() it regrows
local picked = {}

for id, field in pairs(Config.Fields) do
    positions[id] = spots.list(field)
end

local function publish()
    local list = {}

    for key in pairs(picked) do list[key] = true end

    GlobalState.cityDrugsPicked = list
end

---The field and spot position, if the client sent a real one
---@return table?, table?
local function spotOf(fieldId, index)
    local field = type(fieldId) == 'string' and Config.Fields[fieldId]
    if not field or not math.tointeger(index) then return end

    local position = positions[fieldId][index]
    if not position then return end

    return field, vec3(position.x, position.y, position.z)
end

local function canPick(src, fieldId, index)
    local field, position = spotOf(fieldId, index)

    if not field then
        lib.print.warn(('city_drugs: %s sent an invalid spot %s %s'):format(src, tostring(fieldId), tostring(index)))
        return
    end

    if picked[spots.key(fieldId, index)] then return end
    -- the spot's z is the field's centre; the prop sits on the ground, so allow some height
    if not common.near(src, position, Config.UseDistance + 3.0) then return end

    return field, position
end

lib.callback.register('city_drugs:startPick', function(source, fieldId, index)
    local src = source
    if not common.player(src) then return false end

    local field = canPick(src, fieldId, index)
    if not field then return false end

    common.start(src, spots.key(fieldId, index), field.seconds)

    return true
end)

lib.callback.register('city_drugs:pick', function(source, fieldId, index)
    local src = source
    if not common.player(src) then return false end

    local key = spots.key(tostring(fieldId), math.tointeger(index) or 0)
    if not common.finish(src, key) then return false end

    local field, position = canPick(src, fieldId, index)
    if not field then return false end

    local numbers = settings.fields[fieldId]
    local amount = math.random(numbers.min, numbers.max)

    if not exports.city_inventory:CanCarryItem(src, field.item, amount) then return false, 'full' end
    if not exports.city_inventory:AddItem(src, field.item, amount) then return false end

    picked[key] = os.time() + numbers.regrowMinutes * 60
    publish()

    common.alert(field.drug, 'pick', locale('alert_field', field.label), position)

    return true, amount
end)

CreateThread(function()
    publish()

    while true do
        Wait(REGROW_CHECK_MS)

        local now, changed = os.time(), false

        for key, regrowsAt in pairs(picked) do
            if now >= regrowsAt then
                picked[key] = nil
                changed = true
            end
        end

        if changed then publish() end
    end
end)
