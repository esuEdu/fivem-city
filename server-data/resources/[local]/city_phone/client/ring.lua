-- Ringing phones: the server sets a player's phoneRinging state bag (exports.city_phone:SetRinging). Everyone close
-- by hears it from their own phone page, quieter with distance; your own phone in silent mode only vibrates.
local CHECK_MS = 250

---@type table<integer, { tone: string, loud: boolean }>
local ringing = {}
local looping = false

local function volumes()
    local list = {}
    local coords = GetEntityCoords(cache.ped)

    for serverId, ring in pairs(ringing) do
        if serverId == cache.serverId then
            list[#list + 1] = { id = serverId, tone = ring.tone, volume = ring.loud and 1.0 or 0.0, vibrate = true }
        elseif ring.loud then
            local player = GetPlayerFromServerId(serverId)
            local ped = player ~= -1 and GetPlayerPed(player)

            -- Gone out of range: its "stopped" state may never reach us, so forget it
            if not ped or ped == 0 then ringing[serverId] = nil end

            if ped and ped ~= 0 then
                local distance = #(coords - GetEntityCoords(ped))

                if distance < Config.RingDistance then
                    list[#list + 1] = { id = serverId, tone = ring.tone, volume = (1.0 - distance / Config.RingDistance) * 0.8 }
                end
            end
        end
    end

    return list
end

-- Runs only while some phone rings
local function loop()
    if looping then return end
    looping = true

    while next(ringing) do
        SendNUIMessage({ action = 'ring', rings = volumes() })
        Wait(CHECK_MS)
    end

    SendNUIMessage({ action = 'ring', rings = {} })
    looping = false
end

AddStateBagChangeHandler('phoneRinging', nil, function(bagName, _, value)
    local player = GetPlayerFromStateBagName(bagName)
    if not player or player == 0 then return end

    local serverId = GetPlayerServerId(player)

    if type(value) == 'table' and type(value.tone) == 'string' then
        ringing[serverId] = { tone = value.tone, loud = value.loud == true }
        CreateThread(loop)
    else
        ringing[serverId] = nil
    end
end)
