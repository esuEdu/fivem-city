-- The Management tab: every faction member (online or not) with their week's farm net, and for the leader hiring
-- by server id (the player accepts on screen), grade changes below their own and removal.
local orgs = require 'server.orgs'
local farm = require 'server.farm'
local core = require 'server.app.main'

---@param faction Faction
---@param me string the viewer's citizenid
---@return table[]
local function members(faction, me)
    local rows = farm.progressRows(faction.gang, faction, 'weekly', nil)
    local list = {}

    for _, row in ipairs(rows) do
        local online = exports.qbx_core:GetPlayerByCitizenId(row.citizenid)
        local inGang = online and online.PlayerData.gang.name == faction.gang
        local grade = Config.Grades[row.grade]

        list[#list + 1] = {
            citizenid = row.citizenid,
            name = row.name,
            grade = row.grade,
            gradeName = grade and grade.name or tostring(row.grade),
            boss = grade and grade.isboss == true or false,
            online = inGang == true,
            week = row.net,
            me = row.citizenid == me,
        }
    end

    table.sort(list, function(a, b)
        if a.online ~= b.online then return a.online end
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)

    return list
end

core.register('team', function(_, player, faction)
    return true, members(faction, player.PlayerData.citizenid)
end)

---A member the leader may change: in the faction, below the leader's own grade, not themselves.
---@param player table the leader
---@param faction Faction
---@param citizenid unknown
---@return string?
local function subordinate(player, faction, citizenid)
    citizenid = core.citizenid(citizenid)
    if not citizenid or citizenid == player.PlayerData.citizenid then return end

    for _, member in ipairs(exports.qbx_core:GetGroupMembers(faction.gang, 'gang') or {}) do
        if member.citizenid == citizenid and member.grade < player.PlayerData.gang.grade.level then return citizenid end
    end
end

core.register('setGrade', function(src, player, faction, data)
    local citizenid = subordinate(player, faction, data.citizenid)
    local grade = math.tointeger(data.grade)

    if not citizenid or not grade then return false, 'invalid' end
    if not Config.Grades[grade] or grade >= player.PlayerData.gang.grade.level then return false, 'invalid' end
    if not exports.qbx_core:AddPlayerToGang(citizenid, faction.gang, grade) then return false, 'failed' end

    orgs.log(faction.gang, player.PlayerData.citizenid, 'grade', ('%s -> %s'):format(citizenid, Config.Grades[grade].name))
    lib.print.info(('city_orgs: %s (%s) set %s to grade %d in %s'):format(player.PlayerData.citizenid, src, citizenid, grade, faction.gang))
    orgs.refresh(faction.gang, 'data')

    return true
end, { boss = true })

core.register('fire', function(src, player, faction, data)
    local citizenid = subordinate(player, faction, data.citizenid)
    if not citizenid then return false, 'invalid' end
    if not exports.qbx_core:RemovePlayerFromGang(citizenid, faction.gang) then return false, 'failed' end

    orgs.log(faction.gang, player.PlayerData.citizenid, 'fire', citizenid)
    lib.print.info(('city_orgs: %s (%s) removed %s from %s'):format(player.PlayerData.citizenid, src, citizenid, faction.gang))
    orgs.refresh(faction.gang, 'data')

    return true
end, { boss = true })

---@param gang string
---@param citizenid string
---@return boolean
local function isMember(gang, citizenid)
    for _, member in ipairs(exports.qbx_core:GetGroupMembers(gang, 'gang') or {}) do
        if member.citizenid == citizenid then return true end
    end

    return false
end

---@type table<integer, true> players with an offer on screen
local pending = {}

-- The leader offers the faction to any online player by server id; the player accepts or declines on their screen
-- and starts at the lowest grade. The leader hears the answer.
core.register('offer', function(src, player, faction, data)
    local target = math.tointeger(data.target)
    local offered = target and target ~= src and exports.qbx_core:GetPlayer(target)
    if not offered then return false, 'no_player' end
    if offered.PlayerData.gang.name ~= 'none' then return false, 'already' end
    if pending[target] then return false, 'pending' end

    pending[target] = true

    local boss = orgs.fullName(player)
    local name = orgs.fullName(offered)

    CreateThread(function()
        local accepted = lib.callback.await('city_orgs:orgOffer', target, faction.label, Config.Grades[0].name, boss) == true
        pending[target] = nil

        local now = exports.qbx_core:GetPlayer(target)
        if not now or now.PlayerData.citizenid ~= offered.PlayerData.citizenid then return end

        -- The leader may have lost the grade, or someone else recruited them, while the offer was open
        local stillBoss = exports.qbx_core:GetPlayer(src)
        local stillLeads = stillBoss and stillBoss.PlayerData.gang.name == faction.gang and stillBoss.PlayerData.gang.isboss

        if accepted and stillLeads and now.PlayerData.gang.name == 'none' and not isMember(faction.gang, now.PlayerData.citizenid)
            and exports.qbx_core:SetGang(target, faction.gang, 0) then
            exports.qbx_core:Notify(target, locale('hired_you', faction.label), 'success')
            orgs.log(faction.gang, player.PlayerData.citizenid, 'hire', now.PlayerData.citizenid)
            lib.print.info(('city_orgs: %s (%s) recruited %s into %s'):format(player.PlayerData.citizenid, src, now.PlayerData.citizenid, faction.gang))

            if GetPlayerName(src) then
                exports.qbx_core:Notify(src, locale('offer_accepted', name), 'success')
                orgs.refresh(faction.gang, 'data')
            end

            return
        end

        if GetPlayerName(src) then exports.qbx_core:Notify(src, locale('offer_declined', name), 'error') end
    end)

    return true, name
end, { boss = true })

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)
