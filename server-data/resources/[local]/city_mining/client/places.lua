-- NPCs spawned near the player (with ox_target options) and their blips, shared by the shop, smelter, jeweler and
-- crime buyer files. Everything is removed when the resource stops.
local places = {}

local peds = {}
local points = {}
local blips = {}
local icons = {}

---@param model integer
---@param coords vector4
---@param options table[]?
---@return integer ped
local function spawnPed(model, coords, options)
    lib.requestModel(model)

    local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, Config.PedScenario, 0, true)
    if options then exports.ox_target:addLocalEntity(ped, options) end

    return ped
end

---@param coords vector3|vector4
---@param blip table { sprite, color }
---@param label string
---@return integer
function places.blip(coords, blip, label)
    local handle = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(handle, blip.sprite)
    SetBlipColour(handle, blip.color)
    SetBlipScale(handle, 0.7)
    SetBlipAsShortRange(handle, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(handle)
    blips[#blips + 1] = handle

    return handle
end

---@param key string
---@param model integer
---@param coords vector4
---@param options table[]? ox_target options on the ped
---@param icon? { icon: string, label: string, onUse: function } a city_points icon over the ped instead (used with E)
function places.add(key, model, coords, options, icon)
    places.remove(key)

    if icon then
        icons[key] = exports.city_points:Add({
            coords = coords.xyz, ped = true, icon = icon.icon, label = icon.label, onUse = icon.onUse,
        })
    end

    points[key] = lib.points.new({
        coords = coords.xyz,
        distance = Config.PedDistance,
        onEnter = function()
            if not peds[key] then peds[key] = spawnPed(model, coords, options) end
        end,
        onExit = function()
            local ped = peds[key]
            if not ped then return end

            exports.ox_target:removeLocalEntity(ped)
            DeleteEntity(ped)
            peds[key] = nil
        end,
    })
end

---@param key string
function places.remove(key)
    if icons[key] then
        exports.city_points:Remove(icons[key])
        icons[key] = nil
    end

    local ped = peds[key]
    if ped then
        exports.ox_target:removeLocalEntity(ped)
        DeleteEntity(ped)
        peds[key] = nil
    end

    if points[key] then
        points[key]:remove()
        points[key] = nil
    end
end

---@param ok boolean
---@param result any
---@param successKey string
---@param ... any
function places.report(ok, result, successKey, ...)
    if ok then
        lib.notify({ description = locale(successKey, ...), type = 'success' })
    else
        lib.notify({ description = locale(result or 'invalid'), type = 'error' })
    end
end

---@param name string
---@return string
function places.label(name)
    local item = exports.city_inventory:Items(name)
    return item and item.label or name
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for key in pairs(points) do places.remove(key) end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
end)

return places
