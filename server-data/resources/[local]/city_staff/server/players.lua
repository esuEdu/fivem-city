-- The player list and everything staff do to one player (except warnings, kicks and bans: server/sanctions.lua).

local rules = require 'shared.rules'
local staff = require 'server.staff'

---@type table<integer, true> players frozen by staff
local frozen = {}

---@type table<integer, integer> staff spectating -> the routing bucket they came from
local spectating = {}

---@type table<integer, integer> server id -> os.time() they joined (players already on when this started count from then)
local joined = {}
local startedAt = os.time()

AddEventHandler('playerJoining', function()
    joined[source] = os.time()
end)

---Health as a percentage: a ped's health runs from 100 (dead) to its max (200 for players).
---@param ped integer
---@return integer
local function healthPercent(ped)
    local max = GetEntityMaxHealth(ped)
    if max <= 100 then return 0 end

    return math.max(0, math.min(100, math.floor((GetEntityHealth(ped) - 100) / (max - 100) * 100 + 0.5)))
end

---@param src integer
---@return table row as the player list shows it
local function row(src)
    local player = exports.qbx_core:GetPlayer(src)
    local data = player.PlayerData

    return {
        id = src,
        name = ('%s %s'):format(data.charinfo.firstname, data.charinfo.lastname),
        account = GetPlayerName(src),
        citizenid = data.citizenid,
        job = data.job.label,
        health = healthPercent(GetPlayerPed(src)),
        online = os.time() - (joined[src] or startedAt),
    }
end

staff.register('players', function()
    local list = {}

    for src in pairs(exports.qbx_core:GetQBPlayers()) do
        list[#list + 1] = row(src)
    end

    table.sort(list, function(a, b) return a.id < b.id end)

    return true, list
end, 'app')

staff.register('player', function(_, data)
    local target = rules.toId(data.target)
    local player = target and exports.qbx_core:GetPlayer(target)
    if not player then return false, 'no_player' end

    local info = row(target)
    local playerData = player.PlayerData
    local license = GetPlayerIdentifierByType(tostring(target), 'license2') or GetPlayerIdentifierByType(tostring(target), 'license')

    info.jobName = playerData.job.name
    info.jobLevel = playerData.job.grade and playerData.job.grade.level or 0
    info.jobGrade = playerData.job.grade and playerData.job.grade.name
    info.gangName = playerData.gang.name
    info.gangLevel = playerData.gang.grade and playerData.gang.grade.level or 0
    info.gang = playerData.gang.label
    info.gangGrade = playerData.gang.grade and playerData.gang.grade.name
    info.ping = GetPlayerPing(tostring(target))
    info.bucket = GetPlayerRoutingBucket(tostring(target))
    info.frozen = frozen[target] == true
    info.staff = Config.Levels[staff.rank(target)]
    info.license = license
    info.dead = playerData.metadata.isdead or playerData.metadata.inlaststand or false
    info.cuffed = playerData.metadata.ishandcuffed or false
    local ped = GetPlayerPed(target)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local vehicleInfo = vehicle ~= 0 and exports.qbx_core:GetVehiclesByHash()[GetEntityModel(vehicle)]

    info.armor = GetPedArmour(ped)
    info.hunger = math.floor(tonumber(playerData.metadata.hunger) or 100)
    info.thirst = math.floor(tonumber(playerData.metadata.thirst) or 100)
    info.cash = exports.qbx_core:GetMoney(target, 'cash') or 0
    info.bank = exports.qbx_core:GetMoney(target, 'bank') or 0
    info.coords = GetEntityCoords(ped)
    info.vehicle = vehicle ~= 0 and {
        name = vehicleInfo and ('%s %s'):format(vehicleInfo.brand or '', vehicleInfo.name or ''):gsub('^%s+', '') or nil,
        plate = GetVehicleNumberPlateText(vehicle),
    } or nil
    info.warnings = MySQL.query.await('SELECT `reason`, `staff_name`, UNIX_TIMESTAMP(`created_at`) AS `time` FROM `city_staff_warnings` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 20', { playerData.citizenid }) or {}

    return true, info
end, 'app')

---Puts `who` in `into`'s routing bucket, so they can see each other.
---@param who integer
---@param into integer
local function matchBucket(who, into)
    local bucket = GetPlayerRoutingBucket(tostring(into))

    if GetPlayerRoutingBucket(tostring(who)) ~= bucket then exports.qbx_core:SetPlayerBucket(who, bucket) end
end

staff.register('goto', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true })
    if not target then return false, reason end

    matchBucket(src, target)
    local coords = GetEntityCoords(GetPlayerPed(target))
    SetEntityCoords(GetPlayerPed(src), coords.x, coords.y, coords.z, false, false, false, false)
    staff.log(src, 'goto', target)

    return true
end)

staff.register('bring', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true })
    if not target then return false, reason end

    matchBucket(target, src)
    local coords = GetEntityCoords(GetPlayerPed(src))
    SetEntityCoords(GetPlayerPed(target), coords.x, coords.y, coords.z, false, false, false, false)
    staff.log(src, 'bring', target)

    return true
end)

staff.register('heal', function(src, data)
    local target, reason = staff.target(src, data)
    if not target then return false, reason end

    -- Wounds and bleeding only (qbx_medical's own heal); health and hunger stay as they are
    TriggerClientEvent('qbx_medical:client:heal', target, 'full')
    staff.log(src, 'heal', target)

    return true
end)

staff.register('revive', function(src, data)
    local target, reason = staff.target(src, data)
    if not target then return false, reason end

    local metadata = exports.qbx_core:GetPlayer(target).PlayerData.metadata

    -- Down: a full revive. Alive: just back to full health
    if metadata.isdead or metadata.inlaststand then
        exports.qbx_medical:Revive(target)
    else
        TriggerClientEvent('city_staff:client:fullHealth', target)
    end

    staff.log(src, 'revive', target)

    return true
end)

staff.register('freeze', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true, outrank = true })
    if not target then return false, reason end

    local freeze = not frozen[target]
    frozen[target] = freeze or nil
    FreezeEntityPosition(GetPlayerPed(target), freeze)
    staff.log(src, freeze and 'freeze' or 'unfreeze', target)

    return true, freeze
end)

staff.register('kill', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true, outrank = true })
    if not target then return false, reason end

    TriggerClientEvent('city_staff:client:kill', target)
    staff.log(src, 'kill', target)

    return true
end)

staff.register('cuff', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true, outrank = true })
    if not target then return false, reason end
    if GetResourceState('qbx_police') ~= 'started' then return false, 'unavailable' end

    -- qbx_police's own handler cuffs or uncuffs, whichever the player isn't
    TriggerClientEvent('police:client:GetCuffed', target, src, false)
    staff.log(src, 'cuff', target)

    return true
end)

staff.register('clothing', function(src, data)
    local target, reason = staff.target(src, data)
    if not target then return false, reason end

    TriggerClientEvent('qb-clothing:client:openMenu', target)
    staff.log(src, 'clothing', target)

    return true
end)

-- Only checks and logs: the staff member's client then opens the inventory, and city_inventory checks again
staff.register('inventory', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true })
    if not target then return false, reason end

    staff.log(src, 'inventory', target)

    return true, target
end)

-- The staff member joins the target's routing bucket while watching, and goes back after
staff.register('spectate', function(src, data)
    local target, reason = staff.target(src, data, { notSelf = true })
    if not target then return false, reason end

    if not spectating[src] then spectating[src] = GetPlayerRoutingBucket(tostring(src)) end
    matchBucket(src, target)
    staff.log(src, 'spectate', target)

    return true, { target = target, coords = GetEntityCoords(GetPlayerPed(target)) }
end)

staff.register('stopSpectate', function(src)
    local bucket = spectating[src]
    if not bucket then return true end

    spectating[src] = nil
    exports.qbx_core:SetPlayerBucket(src, bucket)

    return true
end, 'spectate')

AddEventHandler('playerDropped', function()
    local src = source
    frozen[src] = nil
    spectating[src] = nil
    joined[src] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for src in pairs(frozen) do
        FreezeEntityPosition(GetPlayerPed(src), false)
    end
end)
