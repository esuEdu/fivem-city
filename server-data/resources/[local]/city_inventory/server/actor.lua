-- Who may change their inventory right now: loaded, not spamming, not dead or cuffed. Shared by every action handler.

local players = require 'server.players'

local actor = {}

---@type table<integer, { second: integer, count: integer }>
local recentActions = {}

---@param src integer
---@return boolean
local function isRateLimited(src)
    local now = os.time()
    local entry = recentActions[src]

    if not entry or entry.second ~= now then
        entry = { second = now, count = 0 }
        recentActions[src] = entry
    end

    entry.count = entry.count + 1

    return entry.count > Config.ActionsPerSecond
end

---@param value unknown
---@return integer?
function actor.toInteger(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

---Inventory of a player who is allowed to act on it right now.
---@param src integer
---@return Inventory? inventory
---@return string? reason
function actor.getActor(src)
    local inventory = players.get(src)
    if not inventory then return nil, 'busy' end

    if isRateLimited(src) then
        lib.print.warn(('Player %s sent more than %d inventory actions in a second'):format(src, Config.ActionsPerSecond))
        return nil, 'busy'
    end

    local player = exports.qbx_core:GetPlayer(src)
    local metadata = player and player.PlayerData.metadata

    if not metadata or metadata.isdead or metadata.inlaststand or metadata.ishandcuffed or Player(src).state.invBusy then
        return nil, 'busy'
    end

    return inventory
end

AddEventHandler('playerDropped', function()
    recentActions[source] = nil
end)

return actor
