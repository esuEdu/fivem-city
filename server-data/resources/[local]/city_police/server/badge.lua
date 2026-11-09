-- The police badge item: using it shows the officer's badge (department, name, rank, callsign) to them and to every
-- player within Config.Badge.range, for Config.Badge.seconds. Only the police job can show one.

local police = require 'server.police'
local roster = require 'server.roster'

local last = {}

exports.qbx_core:CreateUseableItem(Config.Badge.item, function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    if not police.isCop(src) then return police.notify(src, 'badge_not_yours', 'error') end

    local now = os.time()
    if last[src] and now - last[src] < Config.Badge.cooldown then return end
    last[src] = now

    local unit = roster.unit(src)
    local job = player.PlayerData.job
    local card = {
        department = Config.Badge.department,
        name = police.fullName(player),
        rank = job.grade.name,
        callsign = unit and unit.callsign or nil,
        number = player.PlayerData.citizenid,
        officer = src,
    }

    local coords = GetEntityCoords(GetPlayerPed(src))
    for _, target in ipairs(GetPlayers()) do
        target = tonumber(target)
        if target == src or #(GetEntityCoords(GetPlayerPed(target)) - coords) <= Config.Badge.range then
            TriggerClientEvent('city_police:client:showBadge', target, card)
        end
    end
end)

AddEventHandler('playerDropped', function()
    last[source] = nil
end)
