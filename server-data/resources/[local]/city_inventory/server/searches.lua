-- Searching another player (ox_inventory's openNearbyInventory and openInventory('player', id)): police on duty search
-- anyone next to them, anyone may rob a player who is cuffed, down or has their hands up, and staff on admin duty open
-- anyone's inventory from anywhere. The target's inventory is the second panel; every move checks all of it again.

local players = require 'server.players'
local hooks = require 'server.hooks'

local searches = {}

---@type table<integer, integer> searcher -> the player whose inventory they have open
local sessions = {}

---@param src integer
---@return boolean
local function isStaff(src)
    return IsPlayerAceAllowed(tostring(src), Config.SearchStaffAce) and exports.qbx_core:IsOptin(src) == true
end

---@param player table
---@return boolean
local function isPolice(player)
    local job = player.PlayerData.job

    return job ~= nil and Config.SearchJobTypes[job.type] == true and job.onduty == true
end

-- Hands up is set by the target's own client (scully_emotemenu): they can only lie to stop being robbed that way
---@param target table
---@return boolean
local function isHelpless(target)
    local metadata = target.PlayerData.metadata

    return metadata.isdead or metadata.inlaststand or metadata.ishandcuffed
        or Player(target.PlayerData.source).state.handsup == true
end

---@param src integer
---@param target integer
---@return boolean? staff true for staff, false for police or a robber, nil when they may not
---@return string? reason
local function canSearch(src, target)
    local player = exports.qbx_core:GetPlayer(src)
    local targetPlayer = exports.qbx_core:GetPlayer(target)
    if not player or not targetPlayer or not players.get(target) then return nil, 'no_player' end

    if isStaff(src) then return true end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) > Config.SearchDistance then
        return nil, 'too_far'
    end

    if isPolice(player) or isHelpless(targetPlayer) then return false end

    return nil, 'no_access'
end

---@param src integer
---@return string
local function nameOf(src)
    local player = exports.qbx_core:GetPlayer(src)
    local charinfo = player and player.PlayerData.charinfo

    return charinfo and ('%s %s'):format(charinfo.firstname, charinfo.lastname) or GetPlayerName(src) or tostring(src)
end

---@param src integer
---@param target unknown server id
---@return boolean success
---@return string? reason
function searches.open(src, target)
    target = math.tointeger(tonumber(target))
    if not target or target == src then return false, 'no_player' end

    local staff, reason = canSearch(src, target)
    if staff == nil then return false, reason end

    local inventory = players.get(target) --[[@as Inventory]]

    if not staff and not hooks.run('openInventory', { source = src, inventoryId = target, inventoryType = 'player' }) then
        return false, 'no_access'
    end

    searches.close(src)

    sessions[src] = target
    players.viewers(target)[src] = true

    if staff then
        lib.print.info(('Staff %s (%s) opened the inventory of %s (%s)'):format(GetPlayerName(src), src, GetPlayerName(target), target))
    end

    TriggerClientEvent('city_inventory:client:openOther', src, {
        id = ('player:%d'):format(target),
        label = nameOf(target),
        slots = inventory.slotCount,
        maxWeight = inventory.maxWeight,
        weight = inventory.weight,
        items = inventory.items,
    })

    return true
end

---@param src integer
---@return boolean
function searches.hasSession(src)
    return sessions[src] ~= nil
end

---The inventory the player is searching, if they still may (still close, still police, target still cuffed, ...).
---@param src integer
---@return Inventory? inventory
---@return string? reason
function searches.session(src)
    local target = sessions[src]
    if not target then return nil, 'search_closed' end

    if canSearch(src, target) == nil then
        searches.close(src)
        TriggerClientEvent('city_inventory:client:closeOther', src, 'search_closed')
        return nil, 'search_closed'
    end

    return players.get(target)
end

---@param src integer
function searches.close(src)
    local target = sessions[src]
    if not target then return end

    sessions[src] = nil
    players.viewers(target)[src] = nil
end

return searches
