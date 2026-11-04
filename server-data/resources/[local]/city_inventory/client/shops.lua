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

---@param coords vector3
---@param shop table
local function addBlip(coords, shop)
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
                coords = coords,
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
    for _, zone in ipairs(zones) do exports.ox_target:removeZone(zone) end
    for _, entry in ipairs(models) do exports.ox_target:removeModel(entry.models, entry.name) end
end)
