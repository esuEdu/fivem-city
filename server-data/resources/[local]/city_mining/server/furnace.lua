-- Home furnaces: installed inside a qbx_properties property by its owner or a keyholder, where the player stands.
-- Slower and smaller than the public smelter, no fee and no stamp (copper, iron, steel, gunpowder, homemade dynamite).
local gear = require 'shared.gear'
local orders = require 'server.orders'
local smelting = require 'server.smelting'
local profiles = require 'server.profiles'
local util = require 'server.util'

local RANGE = 3.0

---@type table<integer, table> property id -> { citizenid, coords }
local furnaces = {}

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_mining_furnaces` (
            `property_id` INT NOT NULL PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL,
            `x` FLOAT NOT NULL,
            `y` FLOAT NOT NULL,
            `z` FLOAT NOT NULL,
            `h` FLOAT NOT NULL DEFAULT 0
        )
    ]])

    for _, row in ipairs(MySQL.query.await('SELECT `property_id`, `citizenid`, `x`, `y`, `z`, `h` FROM `city_mining_furnaces`') or {}) do
        furnaces[row.property_id] = { citizenid = row.citizenid, coords = vec4(row.x, row.y, row.z, row.h) }
    end
end)

---The property the player is inside and whether they may use it (owner or keyholder).
---@param player table
---@return integer? propertyId
local function property(player)
    local id = math.tointeger(player.PlayerData.metadata.currentPropertyId)
    if not id then return end

    local row = MySQL.single.await('SELECT `owner`, `keyholders` FROM `properties` WHERE `id` = ?', { id })
    if not row then return end

    local citizenid = player.PlayerData.citizenid
    if row.owner == citizenid then return id end

    local keyholders = row.keyholders and json.decode(row.keyholders) or {}
    for _, holder in pairs(keyholders) do
        if holder == citizenid then return id end
    end
end

---@param id integer
---@return string
local function place(id)
    return ('home:%d'):format(id)
end

---@param src integer
---@param player table
---@return integer? propertyId
---@return table? furnace
local function atFurnace(src, player)
    local id = property(player)
    local furnace = id and furnaces[id]
    if not furnace or not util.near(src, furnace.coords, RANGE) then return end

    return id, furnace
end

exports.qbx_core:CreateUseableItem(gear.furnace.item, function(source, item)
    if not Config.Features.furnace then return false end
    local src = source
    local player = util.player(src)
    if not player then return false end

    local id = property(player)
    if not id then return util.notify(src, 'furnace_inside_home', 'error') end
    if furnaces[id] then return util.notify(src, 'furnace_exists', 'error') end

    if not exports.city_inventory:RemoveItem(src, gear.furnace.item, 1, nil, item.slot) then return false end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local forward = vec3(-math.sin(math.rad(heading)), math.cos(math.rad(heading)), 0.0)
    local at = coords + forward * 1.0

    MySQL.insert.await('INSERT INTO `city_mining_furnaces` (`property_id`, `citizenid`, `x`, `y`, `z`, `h`) VALUES (?, ?, ?, ?, ?, ?)', {
        id, player.PlayerData.citizenid, at.x, at.y, at.z - 1.0, heading,
    })
    furnaces[id] = { citizenid = player.PlayerData.citizenid, coords = vec4(at.x, at.y, at.z - 1.0, heading) }

    util.notify(src, 'furnace_installed', 'success')
    TriggerClientEvent('city_mining:client:furnaceChanged', src)

    return false
end)

-- Where the furnace of the property the player is in stands, for the client to draw it
lib.callback.register('city_mining:furnaceHere', function(source)
    if not Config.Features.furnace then return false end
    local player = util.player(source)
    if not player then return false end

    local id = property(player)
    local furnace = id and furnaces[id]
    if not furnace then return false end

    local c = furnace.coords

    return true, { x = c.x, y = c.y, z = c.z, h = c.w }
end)

lib.callback.register('city_mining:furnaceInfo', function(source)
    if not Config.Features.furnace then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    local id = atFurnace(src, player)
    if not id then return false, 'too_far' end

    local profile = profiles.get(citizenid)
    local recipes = {}

    for _, name in ipairs({ 'copper', 'iron', 'steel', 'gunpowder', 'homemade_dynamite' }) do
        local quote = smelting.quote(profile, name, 1, true)
        if quote then recipes[#recipes + 1] = { name = name, inputs = quote.inputs, seconds = quote.seconds } end
    end

    return true, {
        order = smelting.view(orders.at(place(id))),
        recipes = recipes,
        maxBatch = smelting.maxBatch(profile, true),
        owner = furnaces[id].citizenid == citizenid,
    }
end)

lib.callback.register('city_mining:furnaceSmelt', function(source, name, count)
    if not Config.Features.furnace then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    local id = atFurnace(src, player)
    if not id then return false, 'too_far' end

    return smelting.start(src, citizenid, place(id), name, count, true)
end)

lib.callback.register('city_mining:furnaceCollect', function(source)
    if not Config.Features.furnace then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    local id = atFurnace(src, player)
    if not id then return false, 'too_far' end

    local order = orders.at(place(id))
    if not order then return false, 'no_order' end

    return smelting.collect(src, citizenid, order)
end)

lib.callback.register('city_mining:furnacePickUp', function(source)
    if not Config.Features.furnace then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    local id, furnace = atFurnace(src, player)
    if not id then return false, 'too_far' end
    if furnace.citizenid ~= citizenid then return false, 'not_owner' end
    if orders.at(place(id)) then return false, 'order_open' end
    if not exports.city_inventory:CanCarryItem(src, gear.furnace.item, 1) then return false, 'inventory_full' end

    MySQL.prepare.await('DELETE FROM `city_mining_furnaces` WHERE `property_id` = ?', { id })
    furnaces[id] = nil
    exports.city_inventory:AddItem(src, gear.furnace.item, 1)
    TriggerClientEvent('city_mining:client:furnaceChanged', src)

    return true
end)
