-- Labs: going in through the door, and batches at each station. The recipe's inputs and outputs come from config; the
-- client only says which lab and recipe.
local common = require 'server.common'
local rules = require 'server.rules'

---The lab and recipe, if the player stands at that station
---@return table?, table?
local function recipeOf(src, labId, index)
    local lab = type(labId) == 'string' and Config.Labs[labId]
    local recipe = lab and math.tointeger(index) and lab.recipes[index]

    if not recipe then
        lib.print.warn(('city_drugs: %s sent an invalid recipe %s %s'):format(src, tostring(labId), tostring(index)))
        return
    end

    if not common.near(src, recipe.coords, Config.StationRadius + Config.UseDistance + 1.0) then return end

    return lab, recipe
end

local function inputNames(recipe)
    local names = {}

    for item in pairs(recipe.inputs) do names[#names + 1] = item end

    return names
end

local function outputCount(recipe)
    local count = 0

    for _, amount in pairs(recipe.outputs) do count = count + amount end

    return count
end

-- The door: only gang members get in (server/config.lua gangOnly.labs). Leaving needs no check.
lib.callback.register('city_drugs:enterLab', function(source, labId)
    local src = source
    local player, reason = common.player(src, 'labs')
    if not player then return false, reason end

    local lab = type(labId) == 'string' and Config.Labs[labId]
    if not lab then return false end

    if not common.near(src, lab.entrance, Config.UseDistance + 2.0) then return false end

    return true
end)

lib.callback.register('city_drugs:startBatch', function(source, labId, index)
    local src = source
    local player, reason = common.player(src, 'labs')
    if not player then return false, reason end

    local _, recipe = recipeOf(src, labId, index)
    if not recipe then return false end

    if not rules.canMake(common.counts(src, inputNames(recipe)), recipe.inputs) then return false, 'missing' end

    common.start(src, ('lab:%s:%d'):format(labId, index), recipe.seconds)

    return true
end)

lib.callback.register('city_drugs:batch', function(source, labId, index)
    local src = source
    local player, reason = common.player(src, 'labs')
    if not player then return false, reason end

    if not common.finish(src, ('lab:%s:%d'):format(tostring(labId), math.tointeger(index) or 0)) then return false end

    local lab, recipe = recipeOf(src, labId, index)
    if not recipe then return false end

    local ok, err = common.exchange(src, recipe.inputs, recipe.outputs)
    if not ok then return false, err or 'missing' end

    common.record(src, 'made', labId, outputCount(recipe))
    -- the smell is noticed outside, at the door
    common.alert(labId, 'lab', locale('alert_lab'), lab.entrance)

    return true
end)
