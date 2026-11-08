-- Fish market demand per species: 1.0 at rest, lower for every fish sold, recovering every minute.
local settings = require 'server.config'
local fish = require 'server.fish'

local demand = {}

---@type table<string, number>
local factors = {}

---@param species string
---@return number
function demand.get(species)
    return factors[species] or 1.0
end

---One fish sold; `softer` (0-1, the Merchant skill) makes this seller's sale lower the price less.
---@param species string
---@param softer number
function demand.sold(species, softer)
    local drop = settings.market.dropPerFish * (1 - softer)
    factors[species] = math.max(settings.market.floor, demand.get(species) - drop)
end

function demand.recover()
    for species, factor in pairs(factors) do
        factor = factor + settings.market.recoverPerMinute
        factors[species] = factor < 1.0 and factor or nil
    end
end

---Today's price of every sellable species at 1 star, for the app.
---@return table[]
function demand.prices()
    local list = {}

    for name, entry in pairs(fish.byName) do
        if entry.price and not entry.junk and not entry.legendary then
            list[#list + 1] = { name = name, label = entry.label, price = entry.price, demand = demand.get(name) }
        end
    end

    table.sort(list, function(a, b) return a.label < b.label end)

    return list
end

return demand
