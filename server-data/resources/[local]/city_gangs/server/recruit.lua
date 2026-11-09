-- The Recruit tab: invite a nearby player who has no gang. They are asked on their screen and join at the lowest grade
-- only if they accept; the invite is checked again when they answer.
local rules = require 'shared.rules'
local gang = require 'server.gang'
local log = require 'server.log'

---@type table<integer, { gang: string, from: integer, expiresAt: integer }> invited player -> their invite
local invites = {}

---Players next to `src` who have no gang
---@param src integer
---@return { id: integer, player: table }[]
local function nearbyFree(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return {} end

    local list = {}

    for _, nearby in ipairs(lib.getNearbyPlayers(GetEntityCoords(ped), Config.InviteDistance)) do
        local id = tonumber(nearby.id)
        local player = id and id ~= src and exports.qbx_core:GetPlayer(id)

        if player and gang.isFree(player) then list[#list + 1] = { id = id, player = player } end
    end

    return list
end

gang.register('nearby', function(src)
    local list = {}

    for _, entry in ipairs(nearbyFree(src)) do
        list[#list + 1] = { id = entry.id, name = gang.name(entry.player.PlayerData.charinfo), invited = invites[entry.id] ~= nil }
    end

    return true, list
end, 'recruit')

gang.register('invite', function(src, player, group, data)
    local target = math.tointeger(data.target)
    if not target then return false, 'invalid' end

    local found

    for _, entry in ipairs(nearbyFree(src)) do
        if entry.id == target then found = entry end
    end

    if not found then return false, 'not_nearby' end

    local pending = invites[target]
    if pending and pending.expiresAt > os.time() then return false, 'already_invited' end

    invites[target] = { gang = group.name, from = src, expiresAt = os.time() + Config.InviteSeconds }
    TriggerClientEvent('city_gangs:client:invite', target, group.label, gang.name(player.PlayerData.charinfo))

    return true
end, 'recruit')

lib.callback.register('city_gangs:answer', function(source, accepted)
    local src = source
    local invite = invites[src]
    invites[src] = nil

    if not invite or invite.expiresAt < os.time() then return false, 'expired' end

    local player = exports.qbx_core:GetPlayer(src)
    if not player or not gang.isFree(player) then return false, 'failed' end

    local inviter = exports.qbx_core:GetPlayer(invite.from)
    local group = inviter and gang.of(inviter)

    if accepted ~= true then
        if inviter then gang.notify(invite.from, locale('notify_declined', gang.name(player.PlayerData.charinfo)), 'error') end
        return true
    end

    -- the inviter may have been fired or demoted, or walked away, since asking
    if not group or group.name ~= invite.gang or not rules.can(Config.Permissions, group.grade, 'recruit') then return false, 'expired' end

    local here, there = GetEntityCoords(GetPlayerPed(src)), GetEntityCoords(GetPlayerPed(invite.from))
    if #(here - there) > Config.InviteDistance * 2 then return false, 'not_nearby' end

    local citizenid = player.PlayerData.citizenid
    local ok = exports.qbx_core:AddPlayerToGang(citizenid, group.name, 0)
    if not ok then return false, 'failed' end

    exports.qbx_core:SetPlayerPrimaryGang(citizenid, group.name)
    log.add(group.name, gang.who(inviter), 'hire', gang.who(player))
    gang.notify(invite.from, locale('notify_joined_inviter', gang.name(player.PlayerData.charinfo)), 'success')

    return true, group.label
end)

AddEventHandler('playerDropped', function()
    invites[source] = nil
end)
