-- Blowing an ATM open: plant the C4 (progress bar), then the fuse runs on the server
local atm = Config.Atm

local busy = false
local charge

local function removeCharge()
    if charge and DoesEntityExist(charge) then DeleteEntity(charge) end
    charge = nil
end

---A C4 stuck on the ATM's front, seen by the robber only
---@param entity integer
local function placeCharge(entity)
    removeCharge()
    lib.requestModel(atm.c4Prop)

    local coords = GetOffsetFromEntityInWorldCoords(entity, 0.0, -0.25, 1.0)
    charge = CreateObject(atm.c4Prop, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(charge, GetEntityHeading(entity))
    FreezeEntityPosition(charge, true)
    SetModelAsNoLongerNeeded(atm.c4Prop)
end

local function plant(entity)
    if busy or not DoesEntityExist(entity) then return end

    local ok, reason = lib.callback.await('city_robbery:plantAtm', false, GetEntityCoords(entity))
    if not ok then
        if reason then lib.notify({ description = locale(reason), type = 'error' }) end
        return
    end

    busy = true

    local done = lib.progressBar({
        duration = atm.plantSeconds * 1000,
        label = locale('planting'),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@heists@ornate_bank@thermal_charge', clip = 'thermal_charge', flag = 1 },
    })

    if not done then
        lib.callback.await('city_robbery:cancel', false)
        busy = false
        return
    end

    local armed, result = lib.callback.await('city_robbery:armAtm', false)
    busy = false

    if not armed then
        if result then lib.notify({ description = locale(result), type = 'error' }) end
        return
    end

    placeCharge(entity)
    lib.notify({ description = locale('armed', result), type = 'warning', duration = 6000 })
end

RegisterNetEvent('city_robbery:client:explode', function(coords)
    removeCharge()
    AddExplosion(coords.x, coords.y, coords.z + 1.0, atm.explosionType, atm.explosionDamage, true, false, 1.0)
    lib.notify({ description = locale('atm_open'), type = 'success' })
end)

exports.ox_target:addModel(atm.models, {
    {
        name = 'city_robbery:atm',
        label = locale('plant_c4'),
        icon = 'fas fa-bomb',
        items = atm.item,
        distance = 1.5,
        canInteract = function() return not busy end,
        onSelect = function(data) plant(data.entity) end,
    },
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    removeCharge()
    exports.ox_target:removeModel(atm.models, 'city_robbery:atm')
end)
