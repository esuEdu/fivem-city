-- Robbing a 24/7: an ox_target option at each 24/7 counter of city_inventory's shop list
local store = Config.Store
local locations = require('@city_inventory.data.shops').General.locations

local zones = {}
local busy = false

local function rob(id)
    if busy then return end

    local ok, result = lib.callback.await('city_robbery:startStore', false, id)
    if not ok then
        lib.notify({ description = locale(result or 'failed'), type = 'error' })
        return
    end

    -- Staff past the police rule: the same notice everyone gets, plus the override line
    if result == true then
        lib.notify({ title = locale('no_police'), description = locale('staff_override'), type = 'warning', duration = 8000 })
    end

    busy = true

    local done = lib.progressBar({
        duration = store.seconds * 1000,
        label = locale('robbing'),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'oddjobs@shop_robbery@rob_till', clip = 'loop', flag = 1 },
    })

    if not done then
        lib.notify({ description = locale('cancelled'), type = 'error' })
        lib.callback.await('city_robbery:cancel', false)
        busy = false
        return
    end

    local finished, reason = lib.callback.await('city_robbery:finishStore', false)
    busy = false

    if finished then
        lib.notify({ description = locale('bag_dropped'), type = 'success' })
    else
        lib.notify({ description = locale(reason or 'failed'), type = 'error' })
    end
end

for id, coords in ipairs(locations) do
    zones[#zones + 1] = exports.ox_target:addSphereZone({
        coords = coords.xyz,
        radius = store.targetRadius,
        options = {
            {
                name = ('city_robbery:store:%d'):format(id),
                label = locale('rob_store'),
                icon = 'fas fa-mask',
                canInteract = function() return not busy end,
                onSelect = function() rob(id) end,
            },
        },
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for i = 1, #zones do exports.ox_target:removeZone(zones[i]) end
end)
