-- Live locations shared with this player: a blip per share that moves with each update from the server, removed when
-- the share ends. The page also gets the latest position for its "show on map" button.
local blips = {}

local function remove(id)
    if blips[id] then RemoveBlip(blips[id]) end
    blips[id] = nil
end

RegisterNetEvent('city_phone_messages:client:live', function(id, data)
    if GetInvokingResource() or type(id) ~= 'number' then return end

    exports.city_phone:SendAppMessage('messages', { action = 'live', session = id, data = data })

    if type(data) ~= 'table' then return remove(id) end

    local blip = blips[id]

    if not blip then
        blip = AddBlipForCoord(data.x, data.y, data.z)
        SetBlipSprite(blip, 480)
        SetBlipColour(blip, 2)
        SetBlipScale(blip, 0.9)
        SetBlipCategory(blip, 7)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(('Live: %s'):format(data.number))
        EndTextCommandSetBlipName(blip)
        blips[id] = blip
    else
        SetBlipCoords(blip, data.x, data.y, data.z)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    for id in pairs(blips) do remove(id) end
end)
