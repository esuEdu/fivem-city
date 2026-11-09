-- "Check vehicle" on any car (ox_target): read-only, from what every client already sees of the car
local PERFORMANCE = {
    { mod = 11, key = 'engine' },
    { mod = 12, key = 'brakes' },
    { mod = 13, key = 'transmission' },
    { mod = 15, key = 'suspension' },
    { mod = 16, key = 'armor' },
}

local TURBO_MOD = 18
local NO_MOD_KIT = 65535

local busy = false

---@param value number 0-100
---@return string
local function scheme(value)
    if value >= 70 then return 'green' end
    if value >= 35 then return 'yellow' end
    return 'red'
end

---@param value number
---@return integer
local function percent(value)
    return math.floor(math.max(0, math.min(100, value)) + 0.5)
end

---@param vehicle integer
---@return table[]
local function readVehicle(vehicle)
    -- mod counts read 0 until a kit is set; only changes this client's copy
    if GetVehicleModKit(vehicle) == NO_MOD_KIT then SetVehicleModKit(vehicle, 0) end

    local options = {}

    for i = 1, #PERFORMANCE do
        local part = PERFORMANCE[i]
        local count = GetNumVehicleMods(vehicle, part.mod)
        local fitted = GetVehicleMod(vehicle, part.mod)
        local value

        if count == 0 then
            value = locale('inspect_unavailable')
        elseif fitted < 0 then
            value = locale('stock')
        else
            value = locale('inspect_level', fitted + 1, count)
        end

        options[#options + 1] = {
            title = locale(('inspect_%s'):format(part.key)),
            description = value,
            icon = 'fas fa-gear',
            readOnly = true,
        }
    end

    options[#options + 1] = {
        title = locale('inspect_turbo'),
        description = locale(IsToggleModOn(vehicle, TURBO_MOD) and 'inspect_fitted' or 'inspect_none'),
        icon = 'fas fa-fan',
        readOnly = true,
    }

    local body = percent(GetVehicleBodyHealth(vehicle) / 10)
    local engine = percent(GetVehicleEngineHealth(vehicle) / 10)
    local fuel = percent(Entity(vehicle).state.fuel or GetVehicleFuelLevel(vehicle))

    options[#options + 1] = {
        title = locale('inspect_body'),
        description = ('%d%%'):format(body),
        icon = 'fas fa-car-burst',
        progress = body,
        colorScheme = scheme(body),
        readOnly = true,
    }

    options[#options + 1] = {
        title = locale('inspect_engine_health'),
        description = ('%d%%'):format(engine),
        icon = 'fas fa-oil-can',
        progress = engine,
        colorScheme = scheme(engine),
        readOnly = true,
    }

    options[#options + 1] = {
        title = locale('inspect_fuel'),
        description = ('%d%%'):format(fuel),
        icon = 'fas fa-gas-pump',
        progress = fuel,
        colorScheme = scheme(fuel),
        readOnly = true,
    }

    return options
end

---@param vehicle integer
local function inspect(vehicle)
    if busy then return end

    busy = true

    local done = lib.progressCircle({
        duration = Config.Inspect.seconds * 1000,
        label = locale('inspecting'),
        position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
    })

    busy = false

    if not done or not DoesEntityExist(vehicle) then
        return exports.qbx_core:Notify(locale('canceled'), 'error')
    end

    lib.registerContext({
        id = 'city_mechanic_inspect',
        title = locale('inspect_title'),
        options = readVehicle(vehicle),
    })
    lib.showContext('city_mechanic_inspect')
end

exports.ox_target:addGlobalVehicle({
    name = 'city_mechanic:inspect',
    label = locale('target_inspect'),
    icon = 'fas fa-magnifying-glass',
    distance = Config.Inspect.distance,
    canInteract = function() return not cache.vehicle and not busy end,
    onSelect = function(data)
        CreateThread(function() inspect(data.entity) end)
    end,
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    exports.ox_target:removeGlobalVehicle('city_mechanic:inspect')
end)
