-- Station places: duty, the armory, lockers and taking out vehicles are city_points icons (used with E); evidence locker,
-- trash, storing vehicles and the impound desk are ox_target zones.
-- Options are shown only to who may use them; the server checks again.

local job = require 'client.job'

local RADIUS = 1.5
local zones = {}
local points = {}

---@param coords vector3
---@param options table[]
---@param radius? number
local function zone(coords, options, radius)
    zones[#zones + 1] = exports.ox_target:addSphereZone({ coords = coords, radius = radius or RADIUS, options = options })
end

local function toggleDuty()
    local onDuty = lib.callback.await('city_police:duty', false)
    if onDuty == nil then return end

    exports.qbx_core:Notify(locale(onDuty and 'duty_on' or 'duty_off'), 'inform')
end

---@param kind 'car' | 'heli'
local function openGarage(kind)
    local certs = lib.callback.await('city_police:myCerts', false) or {}

    local options = {}
    local grade = job.grade()

    for _, entry in ipairs(Config.Vehicles[kind]) do
        local allowed = grade >= entry.grade and (not entry.cert or not Config.Features.certs or certs[entry.cert])

        options[#options + 1] = {
            title = entry.label,
            description = not allowed and (entry.cert and locale('garage_needs_cert') or locale('garage_needs_grade')) or nil,
            icon = kind == 'heli' and 'helicopter' or (entry.model == 'policeb' and 'motorcycle' or 'car'),
            disabled = not allowed,
            onSelect = function()
                local _, reason = lib.callback.await('city_police:spawnVehicle', false, kind, entry.model)
                if reason then job.fail(reason) end
            end,
        }
    end

    lib.registerContext({ id = 'city_police_garage', title = locale('garage'), options = options })
    lib.showContext('city_police_garage')
end

local function storeVehicle()
    local stored = lib.callback.await('city_police:storeVehicle', false)
    exports.qbx_core:Notify(locale(stored and 'vehicle_stored' or 'error_no_vehicle'), stored and 'success' or 'error')
end

---@param seconds integer
---@return string
local function hoursLeft(seconds)
    return ('%dh %02dm'):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

-- The impound desk, for anyone: their impounded cars and the fee
local function openImpoundDesk()
    local list = lib.callback.await('city_police:myImpounds', false)
    if not list or #list == 0 then return exports.qbx_core:Notify(locale('impound_none'), 'inform') end

    local options = {}

    for _, row in ipairs(list) do
        options[#options + 1] = {
            title = ('%s · %s'):format(row.plate, row.model or '?'),
            description = locale('impound_desk_row', row.reason, row.fee),
            icon = 'car',
            onSelect = function()
                local ok, reason, secondsLeft = lib.callback.await('city_police:payImpound', false, row.id)

                if ok then return exports.qbx_core:Notify(locale('impound_released'), 'success') end
                if reason == 'on_hold' and secondsLeft then
                    return exports.qbx_core:Notify(locale('impound_on_hold', hoursLeft(secondsLeft)), 'error')
                end

                job.fail(reason)
            end,
        }
    end

    lib.registerContext({ id = 'city_police_impound', title = locale('impound_desk'), options = options })
    lib.showContext('city_police_impound')
end

for _, station in ipairs(Config.Stations) do
    if station.duty then
        points[#points + 1] = exports.city_points:Add({
            coords = station.duty, icon = 'clock', label = locale('target_duty'),
            canInteract = job.isCop, onUse = function() CreateThread(toggleDuty) end,
        })
    end

    if station.armory then
        points[#points + 1] = exports.city_points:Add({
            -- Every officer sees it, so off duty they learn why it won't open instead of finding nothing there
            coords = station.armory, icon = 'weapon', label = locale('target_armory'),
            canInteract = job.isCop,
            onUse = function()
                if not job.onDuty() then return job.fail('armory_off_duty') end
                TriggerEvent('city_police:client:armory')
            end,
        })
    end

    if station.locker then
        points[#points + 1] = exports.city_points:Add({
            coords = station.locker, icon = 'locker', label = locale('target_locker'),
            canInteract = job.isCop,
            onUse = function() exports.city_inventory:openInventory('stash', 'city_police_locker') end,
        })
    end

    if station.evidence then
        zone(station.evidence, { {
            name = 'city_police:evidence', label = locale('target_evidence'), icon = 'fas fa-box',
            canInteract = job.onDuty,
            onSelect = function() exports.city_inventory:openInventory('stash', 'city_police_evidence') end,
        } })
    end

    if station.trash then
        zone(station.trash, { {
            name = 'city_police:trash', label = locale('target_trash'), icon = 'fas fa-trash',
            canInteract = job.onDuty,
            onSelect = function() exports.city_inventory:openInventory('stash', 'city_police_trash') end,
        } })
    end

    for _, kind in ipairs({ 'car', 'heli' }) do
        local garage = station[kind == 'heli' and 'heli' or 'garage']

        if garage then
            -- Taking a vehicle out is the icon (E); putting it back stays on ox_target, as it is done from beside the car
            points[#points + 1] = exports.city_points:Add({
                coords = garage.menu, icon = 'car', label = locale(kind == 'heli' and 'target_heli' or 'target_garage'),
                useDistance = 3.0, canInteract = job.onDuty,
                onUse = function() CreateThread(function() openGarage(kind) end) end,
            })

            zone(garage.menu, { {
                name = 'city_police:store', label = locale('target_store'), icon = 'fas fa-square-parking',
                canInteract = job.onDuty, onSelect = storeVehicle,
            } }, 3.0)
        end
    end

    if station.impound then
        zone(station.impound, { {
            name = 'city_police:impoundDesk', label = locale('target_impound_desk'), icon = 'fas fa-car-burst',
            onSelect = openImpoundDesk,
        } })
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, id in ipairs(zones) do exports.ox_target:removeZone(id) end
    for _, key in ipairs(points) do exports.city_points:Remove(key) end
end)
