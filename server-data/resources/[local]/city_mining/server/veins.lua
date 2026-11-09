-- Active veins and gravel spots: which points hold one now, what tier and ore, and when the next one appears.
-- Each region is replicated in its own GlobalState key (mining:<region>) and only changes when a vein is taken or
-- appears, so a busy region never resends the others.
local settings = require 'server.config'
local points = require 'server.points'
local rolls = require 'server.rolls'

local veins = {}

---@type table<integer, table> point id -> { point, region, tier, ore, kind }
veins.active = {}
---@type table<integer, integer> point id -> os.time() it was emptied
local cooling = {}
---@type table<string, integer[]> region -> times a new vein is due
local due = {}
---@type table<string, integer> region -> point id of its super rock
veins.super = {}
---@type table<string, integer> region -> os.time() the passage closes
veins.passages = {}

local function key(region)
    return ('mining:%s'):format(region)
end

---@param region string
local function publish(region)
    local list = {}

    for id, vein in pairs(veins.active) do
        if vein.region == region then
            local c = vein.point.coords
            list[#list + 1] = { id = id, x = c.x, y = c.y, z = c.z, h = c.w, tier = vein.tier, ore = vein.ore, kind = vein.kind }
        end
    end

    local superId = veins.super[region]
    local superPoint = superId and points.byId[superId]
    local passage
    local passagePoint = points.of(region, 'passage')[1]

    if passagePoint then
        passage = { x = passagePoint.coords.x, y = passagePoint.coords.y, z = passagePoint.coords.z, h = passagePoint.coords.w, open = veins.passageOpen(region) or nil }
    end

    GlobalState[key(region)] = {
        veins = list,
        super = superPoint and { id = superId, x = superPoint.coords.x, y = superPoint.coords.y, z = superPoint.coords.z, h = superPoint.coords.w } or nil,
        passage = passage,
    }
end

veins.publish = publish

---@param region table Config.Regions entry
---@return integer tier
local function pickTier(region)
    local list = {}
    for tier, share in ipairs(region.tiers or { 1 }) do
        if share > 0 then list[#list + 1] = { weight = share, tier = tier } end
    end

    local pick = rolls.weighted(list, math.random)

    return pick and pick.tier or 1
end

---@param region table
---@return integer how many veins it keeps at once
local function target(region)
    local kind = region.kind == 'gravel' and 'gravel' or 'vein'
    local count = #points.of(region.id, kind)

    -- Leave free points so a new vein moves somewhere else
    return math.min(region.active, math.max(0, count - math.max(1, math.floor(count / 3))))
end

---@param region table
---@return table? point a free point that isn't cooling down
local function freePoint(region)
    local kind = region.kind == 'gravel' and 'gravel' or 'vein'
    local now = os.time()
    local free = {}

    for _, point in ipairs(points.of(region.id, kind)) do
        local cooled = not cooling[point.id] or now - cooling[point.id] >= settings.pointCooldown
        if not veins.active[point.id] and veins.super[region.id] ~= point.id and cooled then free[#free + 1] = point end
    end

    if #free == 0 then return end

    return free[math.random(#free)]
end

---@param region table
---@return boolean spawned
local function spawn(region)
    local point = freePoint(region)
    if not point then return false end

    if region.kind == 'gravel' then
        veins.active[point.id] = { point = point, region = region.id, kind = 'gravel' }
    else
        local tier = pickTier(region)
        local ore = rolls.weighted(settings.tiers[tier].ores, math.random)
        veins.active[point.id] = { point = point, region = region.id, kind = 'vein', tier = tier, ore = ore.item }
    end

    return true
end

---Fills every region up to its count (at start and after staff add points).
function veins.fill()
    for _, region in ipairs(Config.Regions) do
        local count = 0
        for _, vein in pairs(veins.active) do
            if vein.region == region.id then count = count + 1 end
        end

        while count < target(region) - #(due[region.id] or {}) and spawn(region) do count = count + 1 end

        publish(region.id)
    end
end

---Takes a vein (mined or panned out); a new one is due after the tier's respawn time.
---@param id integer point id
function veins.take(id)
    local vein = veins.active[id]
    if not vein then return end

    veins.active[id] = nil
    cooling[id] = os.time()

    local wait = vein.kind == 'gravel' and settings.panning.respawn or settings.tiers[vein.tier].respawn
    local list = due[vein.region] or {}
    list[#list + 1] = os.time() + wait
    due[vein.region] = list

    publish(vein.region)
end

---A point was removed by staff: drop what stood on it.
---@param point table
function veins.forget(point)
    if veins.active[point.id] then
        veins.active[point.id] = nil
    end

    if veins.super[point.region] == point.id then veins.super[point.region] = nil end

    publish(point.region)
end

---Due veins appear; passages close. Called every 30 seconds.
function veins.tick()
    local now = os.time()

    for _, region in ipairs(Config.Regions) do
        local list = due[region.id]
        local changed = false

        if list then
            local kept = {}

            for _, at in ipairs(list) do
                if at <= now and spawn(region) then changed = true else kept[#kept + 1] = at end
            end

            due[region.id] = #kept > 0 and kept or nil
        end

        local closes = veins.passages[region.id]
        if closes and closes <= now then
            veins.passages[region.id] = nil
            changed = true
        end

        if changed then publish(region.id) end
    end
end

---Maybe a super rock appears in each region that has them and has none. Called every superRocks.checkMinutes.
function veins.rollSuperRocks()
    for _, region in ipairs(Config.Regions) do
        if region.superRocks and not veins.super[region.id] and math.random() < settings.superRocks.chance then
            local point = freePoint(region)

            if point then
                veins.super[region.id] = point.id
                publish(region.id)
            end
        end
    end
end

---@param region string
function veins.breakSuper(region)
    veins.super[region] = nil
    publish(region)
end

---@param region string
---@param minutes number
function veins.openPassage(region, minutes)
    veins.passages[region] = os.time() + math.floor(minutes * 60)
    publish(region)
end

---@param region string
function veins.closePassage(region)
    if not veins.passages[region] then return end

    veins.passages[region] = nil
    publish(region)
end

---@param region string
---@return boolean
function veins.passageOpen(region)
    local closes = veins.passages[region]

    return closes ~= nil and closes > os.time()
end

---The region's main tier (for super rocks): the one with the biggest share.
---@param region table
---@return integer
function veins.mainTier(region)
    local best, bestShare = 1, -1

    for tier, share in ipairs(region.tiers or { 1 }) do
        if share > bestShare then best, bestShare = tier, share end
    end

    return best
end

function veins.clear()
    for _, region in ipairs(Config.Regions) do GlobalState[key(region.id)] = nil end
end

return veins
