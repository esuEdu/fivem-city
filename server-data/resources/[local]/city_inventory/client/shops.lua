-- Blips and ox_target options for the shops in data/shops.lua. Opening asks the server, which checks everything again.

local shopData = require 'data.shops'
local other = require 'client.other'

local TARGET_RADIUS = 1.5

---@type integer[]
local blips = {}

---@type integer[]
local zones = {}

---@type { models: integer[], name: string }[]
local models = {}

-- Shopkeepers are local peds, spawned only while the player is near
local PED_DISTANCE = 60.0

---@type table<table, integer> point -> ped
local peds = {}

---@param point table lib.points point with model and coords (vec4)
local function spawnPed(point)
    lib.requestModel(point.model)

    local ped = CreatePed(4, point.model, point.coords.x, point.coords.y, point.coords.z - 1.0, point.heading, false, true)
    SetModelAsNoLongerNeeded(point.model)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    peds[point] = ped
end

---@param point table
local function removePed(point)
    local ped = peds[point]
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end

    peds[point] = nil
end

for _, shop in pairs(shopData) do
    if shop.ped then
        for _, coords in ipairs(shop.locations or {}) do
            lib.points.new({
                coords = coords.xyz,
                distance = PED_DISTANCE,
                model = shop.ped,
                heading = type(coords) == 'vector4' and coords.w or 0.0,
                onEnter = spawnPed,
                onExit = removePed,
            })
        end
    end
end

---@param coords vector3
---@param shop table
local function addBlip(coords, shop)
    coords = coords.xyz
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, shop.blip.id)
    SetBlipColour(blip, shop.blip.colour)
    SetBlipScale(blip, shop.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(shop.name)
    EndTextCommandSetBlipName(blip)

    blips[#blips + 1] = blip
end

-- Blips don't need ox_target, so they go on the map straight away
for _, shop in pairs(shopData) do
    if shop.blip then
        for _, coords in ipairs(shop.locations or {}) do
            addBlip(coords, shop)
        end
    end
end

local function addTargets()
    for shopType, shop in pairs(shopData) do
        local label = locale('target_shop', shop.name)

        for id, coords in ipairs(shop.locations or {}) do
            zones[#zones + 1] = exports.ox_target:addSphereZone({
                coords = coords.xyz,
                radius = TARGET_RADIUS,
                options = {
                    {
                        name = ('city_inventory:%s:%s'):format(shopType, id),
                        label = label,
                        icon = 'fas fa-basket-shopping',
                        groups = shop.groups,
                        onSelect = function() other.openShop(shopType, id) end,
                    },
                },
            })
        end

        if shop.model then
            local name = ('city_inventory:%s'):format(shopType)

            exports.ox_target:addModel(shop.model, {
                {
                    name = name,
                    label = label,
                    icon = 'fas fa-basket-shopping',
                    onSelect = function() other.openShop(shopType) end,
                },
            })

            models[#models + 1] = { models = shop.model, name = name }
        end
    end
end

-- city_inventory starts before ox_target (server.cfg order), so wait for its exports
CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end
    addTargets()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    for point in pairs(peds) do removePed(point) end
    for _, zone in ipairs(zones) do exports.ox_target:removeZone(zone) end
    for _, entry in ipairs(models) do exports.ox_target:removeModel(entry.models, entry.name) end
end)
