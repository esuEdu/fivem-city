-- Demand per item at the ore buyer: 1.0 at rest, lower for every unit sold, recovering every minute.
local settings = require 'server.config'

local demand = {}

---@type table<string, number>
local factors = {}

---@param item string
---@return number
function demand.get(item)
    return factors[item] or 1.0
end

---@param item string
---@param count integer
function demand.sold(item, count)
    local market = settings.market
    local drop = (settings.ingots[item] and market.dropPerIngot or market.dropPerOre) * count
    factors[item] = math.max(market.floor, demand.get(item) - drop)
end

function demand.recover()
    for item, factor in pairs(factors) do
        factor = factor + settings.market.recoverPerMinute
        factors[item] = factor < 1.0 and factor or nil
    end
end

---Today's price list for the app: every item the buyer takes.
---@return table[]
function demand.prices()
    local list = {}

    for item, price in pairs(settings.prices) do
        list[#list + 1] = { name = item, price = price, demand = demand.get(item), ingot = settings.ingots[item] == true }
    end

    table.sort(list, function(a, b) return a.price < b.price end)

    return list
end

return demand
