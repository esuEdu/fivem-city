-- Repair and cleaning kits. The client plays the progress bar; the server takes the item and decides what it fixes.
local mechanic = require 'server.mechanic'

local lastUse = {}

local COOLDOWN = 5

for name in pairs(Config.Kits) do
    exports.qbx_core:CreateUseableItem(name, function(source)
        TriggerClientEvent('city_mechanic:client:useKit', source, name)
    end)
end

lib.callback.register('city_mechanic:kit', function(source, name, netId)
    local src = source
    local kit = type(name) == 'string' and Config.Kits[name]
    if not kit or type(netId) ~= 'number' then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player or player.PlayerData.metadata.isdead or player.PlayerData.metadata.inlaststand then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end
    if not mechanic.near(src, GetEntityCoords(vehicle), Config.KitDistance + 2.0) then return end

    local now = os.time()
    if lastUse[src] and now - lastUse[src] < COOLDOWN then return end
    if exports.city_inventory:GetItemCount(src, name) < 1 then return end
    if not exports.city_inventory:RemoveItem(src, name, 1) then return end

    lastUse[src] = now

    local skilled = mechanic.onDuty(src) ~= nil

    return {
        engine = skilled and kit.mechanicEngine or kit.engine,
        full = skilled and kit.mechanicFull or false,
        clean = kit.clean or false,
    }
end)

AddEventHandler('playerDropped', function()
    lastUse[source] = nil
end)
