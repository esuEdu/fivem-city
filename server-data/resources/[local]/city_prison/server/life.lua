-- Life inside: jobs that take months off, free water and food, and searching hidden spots for contraband parts.
-- Anything that takes time is started and finished on the server, so the wait really happened.

local settings = require 'server.config'
local util = require 'server.util'
local inmates = require 'server.inmates'

local SPOT_RANGE = 3.0
local TOLERANCE_MS = 750

---@type table<integer, { job: string, spot: integer, lastDone?: integer }>
local assigned = {}
---@type table<integer, { kind: string, index: integer, at: integer, seconds: number }>
local pending = {}
---@type table<string, table<string, integer>> citizenid -> what -> os.time() last used
local used = {}
---@type table<integer, integer> contraband spot -> os.time() last searched
local searched = {}

local function inmate(src)
    if not inmates.isInside(src) then return end
    return inmates.serving(src)
end

local function cooledDown(citizenid, what, seconds)
    local byWhat = used[citizenid] or {}
    used[citizenid] = byWhat

    if byWhat[what] and os.time() - byWhat[what] < seconds then return false end

    byWhat[what] = os.time()
    return true
end

local function randomSpot(job, except)
    local spots = Config.Jobs[job].spots
    if #spots == 1 then return 1 end

    local spot
    repeat spot = math.random(#spots) until spot ~= except

    return spot
end

---Begins a timed action; finish() checks it was this one and that the time has passed
local function begin(src, kind, index, seconds)
    pending[src] = { kind = kind, index = index, at = GetGameTimer(), seconds = seconds }
    return seconds
end

local function finish(src, kind, index)
    local action = pending[src]
    pending[src] = nil

    return action ~= nil and action.kind == kind and action.index == index
        and GetGameTimer() - action.at >= action.seconds * 1000 - TOLERANCE_MS
end

-- The job board: take a job (or another spot of it)
lib.callback.register('city_prison:takeJob', function(source, job)
    local src = source
    if util.throttled(src, 'job', 1) or not inmate(src) then return false end
    if type(job) ~= 'string' or not Config.Jobs[job] or not settings.jobs[job] then return false end
    if not util.near(src, Config.JobBoard, SPOT_RANGE) then return false, 'too_far' end

    local current = assigned[src]
    assigned[src] = { job = job, spot = randomSpot(job), lastDone = current and current.lastDone }

    return true, assigned[src].spot
end)

lib.callback.register('city_prison:quitJob', function(source)
    assigned[source] = nil
    pending[source] = nil
    return true
end)

lib.callback.register('city_prison:beginTask', function(source)
    local src = source
    local task = assigned[src]
    if not task or not inmate(src) then return false end

    if task.lastDone and os.time() - task.lastDone < settings.taskCooldown then return false, 'cooldown' end
    if not util.near(src, Config.Jobs[task.job].spots[task.spot], SPOT_RANGE) then return false, 'too_far' end

    return true, begin(src, 'task', task.spot, settings.jobs[task.job].seconds)
end)

-- Done (the electrical skill check failing just never calls this)
lib.callback.register('city_prison:finishTask', function(source)
    local src = source
    local task = assigned[src]
    if not task or not inmate(src) then return false end

    if not finish(src, 'task', task.spot) then
        util.warn(src, 'finished a prison task too early')
        return false
    end

    if not util.near(src, Config.Jobs[task.job].spots[task.spot], SPOT_RANGE) then return false, 'too_far' end

    local taken = inmates.reduce(src, settings.jobs[task.job].months)

    task.lastDone = os.time()
    task.spot = randomSpot(task.job, task.spot)

    return true, { taken = taken, spot = task.spot }
end)

-- Hunger/thirst straight up, as qbx_core's consumables do
local function feed(src, stat, amount)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local metadata = player.PlayerData.metadata
    exports.qbx_core:SetMetadata(src, stat, math.min(100, (metadata[stat] or 0) + amount))

    metadata = player.PlayerData.metadata
    TriggerClientEvent('hud:client:UpdateNeeds', src, metadata.hunger, metadata.thirst)
end

lib.callback.register('city_prison:drink', function(source, index)
    local src = source
    local row = inmate(src)
    local fountain = type(index) == 'number' and Config.Fountains[index]
    if not row or not fountain then return false end
    if not util.near(src, fountain, SPOT_RANGE) then return false, 'too_far' end
    if not cooledDown(row.citizenid, 'water', settings.water.cooldown) then return false, 'cooldown' end

    feed(src, 'thirst', settings.water.amount)
    return true
end)

lib.callback.register('city_prison:eat', function(source)
    local src = source
    local row = inmate(src)
    if not row then return false end
    if not util.near(src, Config.Tray, SPOT_RANGE) then return false, 'too_far' end
    if not cooledDown(row.citizenid, 'tray', settings.tray.cooldown) then return false, 'cooldown' end

    feed(src, 'hunger', settings.tray.amount)
    return true
end)

lib.callback.register('city_prison:beginSearch', function(source, index)
    local src = source
    local row = inmate(src)
    local spot = type(index) == 'number' and Config.Contraband[index]
    if not row or not spot then return false end
    if not util.near(src, spot, SPOT_RANGE) then return false, 'too_far' end

    local last = (used[row.citizenid] or {}).search
    if last and os.time() - last < settings.contraband.playerCooldown then return false, 'cooldown' end

    return true, begin(src, 'search', index, settings.contraband.seconds)
end)

local function rollLoot()
    local total = 0
    for _, entry in ipairs(settings.contraband.loot) do total = total + entry.weight end

    local roll = math.random() * total

    for _, entry in ipairs(settings.contraband.loot) do
        roll = roll - entry.weight
        if roll <= 0 then return entry.item end
    end
end

lib.callback.register('city_prison:finishSearch', function(source, index)
    local src = source
    local row = inmate(src)
    if not row or not finish(src, 'search', index) then return false end
    if not util.near(src, Config.Contraband[index], SPOT_RANGE) then return false, 'too_far' end
    if not cooledDown(row.citizenid, 'search', settings.contraband.playerCooldown) then return false, 'cooldown' end

    -- A spot someone just went through is empty for a while
    local now = os.time()
    local fresh = not searched[index] or now - searched[index] >= settings.contraband.spotCooldown
    searched[index] = now

    if not fresh or math.random(100) > settings.contraband.chance then return true, nil end

    local item = rollLoot()
    if not item or not exports.city_inventory:AddItem(src, item, 1) then return true, nil end

    local definition = exports.city_inventory:Items(item)
    return true, definition and definition.label or item
end)

AddEventHandler('playerDropped', function()
    assigned[source] = nil
    pending[source] = nil
end)

-- Leaving prison ends the job
AddEventHandler('city_prison:server:left', function(src)
    assigned[src] = nil
    pending[src] = nil
end)
