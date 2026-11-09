-- The ore buyer at the smelter: ores, coal, nuggets and ingots, at base price x demand (stamped ingots full price,
-- unstamped ones less). Needs a valid mining licence of the seller's own. Paid in cash (reason mining-sell).
local settings = require 'server.config'
local gear = require 'shared.gear'
local profiles = require 'server.profiles'
local demand = require 'server.demand'
local util = require 'server.util'

---@param item table inventory slot
---@param profile table
---@return number unit price before demand
local function basePrice(item, profile)
    local price = settings.prices[item.name]
    if not price then return 0 end

    if settings.ingots[item.name] then
        local stamped = item.metadata and item.metadata.stamped
        if not stamped then price = price * settings.unstampedShare end
        price = price * (1 + profiles.skill(profile, 'ingot_price'))
    end

    return price
end

lib.callback.register('city_mining:sell', function(source)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    if not util.near(src, Config.Smelter.coords, settings.market.range) then return false, 'too_far' end
    if not util.licence(src, citizenid, gear.licence.item) then return false, 'no_licence' end

    local profile = profiles.get(citizenid)
    local total, sold, taken = 0, 0, {}

    for _, item in pairs(exports.city_inventory:GetInventoryItems(src) or {}) do
        local unit = basePrice(item, profile)

        if unit > 0 and exports.city_inventory:RemoveItem(src, item.name, item.count, item.metadata, item.slot) then
            taken[#taken + 1] = item

            for _ = 1, item.count do
                total = total + unit * demand.get(item.name)
                demand.sold(item.name, 1)
            end

            sold = sold + item.count
        end
    end

    if sold == 0 then return false, 'nothing_to_sell' end

    total = math.floor(total)
    if total > 0 and not exports.qbx_core:AddMoney(src, 'cash', total, 'mining-sell') then
        lib.print.error(('city_mining: paying %s to %s was refused by city_economy'):format(total, citizenid))

        for _, item in ipairs(taken) do
            exports.city_inventory:AddItem(src, item.name, item.count, item.metadata)
        end

        return false, 'payment_failed'
    end

    return true, { sold = sold, total = total }
end)

CreateThread(function()
    while true do
        Wait(60000)
        demand.recover()
    end
end)
