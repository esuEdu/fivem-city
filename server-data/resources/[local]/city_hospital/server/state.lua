-- Who is down, since when, and whether they were finished off. qbx_medical owns the death state (a state bag); this
-- watches it on the server, so the timers can't be faked by a client.
local medical = require '@qbx_medical.config.shared'

local state = {}

local DEATH_BAG = 'qbx_medical:deathState'
local ALIVE = medical.deathState.ALIVE

---@type table<integer, { since: integer, prayed: boolean }>
local down = {}

---Things that end when a player gets up again (calls, carrying, NPC visits) register here
---@type fun(src: integer)[]
local onUp = {}

function state.onUp(fn)
    onUp[#onUp + 1] = fn
end

---@param src integer
---@return table? info
function state.down(src)
    return down[src]
end

---@param src integer
---@return boolean
function state.isFinalized(src)
    local player = exports.qbx_core:GetPlayer(src)

    return player ~= nil and player.PlayerData.metadata.finalized == true
end

---Marks a downed player as finished off: nobody can revive them, only staff or a hospital respawn brings them back.
---Saved in the character's metadata, so relogging doesn't clear it.
---@param src integer
---@param by string citizenid of who did it
function state.finalize(src, by)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    player.Functions.SetMetaData('finalized', true)
    player.Functions.SetMetaData('finalizedBy', by)
    Player(src).state:set('finalized', true, true)
end

---@param src integer
local function clearFinalized(src)
    local player = exports.qbx_core:GetPlayer(src)

    if player and player.PlayerData.metadata.finalized then
        player.Functions.SetMetaData('finalized', false)
        player.Functions.SetMetaData('finalizedBy', nil)
    end

    Player(src).state:set('finalized', false, true)
end

---@param src integer
local function getUp(src)
    down[src] = nil
    clearFinalized(src)

    for i = 1, #onUp do
        local ok, err = pcall(onUp[i], src)
        if not ok then lib.print.error(('city_hospital getting up failed: %s'):format(err)) end
    end
end

---Seconds left before the hospital respawn unlocks
---@param src integer
---@param wait integer
---@return integer
function state.remaining(src, wait)
    local info = down[src]
    if not info then return wait end

    return math.max(0, wait - (os.time() - info.since))
end

---EMS players on duty
---@return integer count
---@return integer[] sources
function state.emsOnDuty()
    local count, list = exports.qbx_core:GetDutyCountType(Config.JobType)

    return count or 0, list or {}
end

---@param src integer
---@return boolean
function state.isEms(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job

    return job ~= nil and job.type == Config.JobType and job.onduty == true
end

-- Revives that went through qbx_medical's server (staff, EMS, the hospital, the NPC ambulance). The death state bag is
-- set by the client, so a finished-off player who sets themselves alive without one of these is put back down.
local revived = {}
local REVIVE_WINDOW = 30

AddEventHandler('qbx_medical:server:revived', function(src)
    if type(src) == 'number' then revived[src] = os.time() end
end)

---@param src integer
---@return boolean
local function realRevive(src)
    local at = revived[src]

    revived[src] = nil

    return at ~= nil and os.time() - at <= REVIVE_WINDOW
end

AddStateBagChangeHandler(DEATH_BAG, nil, function(bagName, _, value)
    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end

    if value == ALIVE or value == nil then
        if down[src] and state.isFinalized(src) and not realRevive(src) then
            exports.city_economy:Flag(src, 'hospital_finalized_bypass', 3, {})
            lib.print.warn(('city_hospital: %s got up while finished off without a revive'):format(src))
            CreateThread(function() lib.callback.await('qbx_medical:client:killPlayer', src) end)
            return
        end

        if down[src] then getUp(src) end
    elseif not down[src] then
        down[src] = { since = os.time(), prayed = false }
    end
end)

AddEventHandler('playerDropped', function()
    local src = source

    revived[src] = nil

    if down[src] then
        down[src] = nil

        for i = 1, #onUp do pcall(onUp[i], src) end
    end
end)

-- Loading a character that logged out finished off keeps the flag visible to others
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local meta = player.PlayerData.metadata
    local finalized = meta.finalized == true

    -- Finished off but loaded up alive (staff revived them offline): the flag is stale
    if finalized and not meta.isdead and not meta.inlaststand then
        player.Functions.SetMetaData('finalized', false)
        finalized = false
    end

    Player(player.PlayerData.source).state:set('finalized', finalized, true)
end)

return state
