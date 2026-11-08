-- The fish market: sells every fish and crustacean the player carries, at base price x stars x skills x demand.
-- Needs a valid licence of the seller's own. Paid in cash (city_economy reason fishing-sell).
local settings = require 'server.config'
local fish = require 'server.fish'
local levels = require 'shared.levels'
local profiles = require 'server.profiles'
local util = require 'server.util'
local demand = require 'server.demand'

---@param entry table
---@param stars integer
---@param skills table
---@return number
local function unitPrice(entry, stars, skills)
    local price = entry.price * (settings.quality[stars] or 1) * (1 + levels.value(skills, 'price'))
    if stars >= 3 then price = price * (1 + levels.value(skills, 'fishmonger')) end

    return price * demand.get(entry.name)
end

---@param src integer
---@return boolean
local function atMarket(src)
    for _, market in ipairs(Config.Markets) do
        if util.near(src, market.coords, settings.market.sellRange) then return true end
    end

    return false
end

lib.callback.register('city_fishing:sell', function(source)
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end

    if not atMarket(src) then return false, 'too_far' end
    if not util.licence(src, citizenid) then return false, 'no_licence' end

    local profile = profiles.get(citizenid)
    local softer = levels.value(profile.skills, 'demand')
    local total, sold, taken = 0, 0, {}

    for _, item in pairs(exports.city_inventory:GetInventoryItems(src) or {}) do
        local entry = fish.byName[item.name]

        if entry and entry.price and not entry.junk then
            local stars = math.tointeger(item.metadata and item.metadata.quality) or 1
            stars = math.max(1, math.min(4, stars))

            if exports.city_inventory:RemoveItem(src, item.name, item.count, item.metadata, item.slot) then
                taken[#taken + 1] = item

                for _ = 1, item.count do
                    total = total + unitPrice(entry, stars, profile.skills)
                    demand.sold(entry.name, softer)
                end

                sold = sold + item.count
            end
        end
    end

    if sold == 0 then return false, 'nothing_to_sell' end

    total = math.floor(total)
    if total > 0 and not exports.qbx_core:AddMoney(src, 'cash', total, 'fishing-sell') then
        lib.print.error(('Fish market: paying %s to %s was refused by city_economy'):format(total, citizenid))

        -- Give the catch back rather than lose it
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
