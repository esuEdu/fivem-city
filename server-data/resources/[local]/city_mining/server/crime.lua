-- The crime buyer: moves every day between hidden points. Buys unstamped ingots above the legal price, gunpowder,
-- dynamite and, at half price, gold, gems and jewellery. No licence asked.
local settings = require 'server.config'
local util = require 'server.util'

local crime = settings.crime

-- Cut gem -> price at 1 star
local cutPrice = {}
for _, gem in pairs(settings.gems) do cutPrice[gem.cut] = gem.cutPrice end

---Today's point (the same for everyone, changes at midnight server time).
---@return vector4
local function todayPoint()
    local day = tonumber(os.date('%j')) or 1

    return crime.points[(day % #crime.points) + 1]
end

local current

local function publish()
    if not Config.Features.crime then
        GlobalState.miningBuyer = nil
        return
    end

    local point = todayPoint()
    if current == point then return end

    current = point
    GlobalState.miningBuyer = { x = point.x, y = point.y, z = point.z, w = point.w }
end

---@param item table slot
---@return number?
local function unitPrice(item)
    local stars = math.max(1, math.min(3, math.tointeger(item.metadata and item.metadata.quality) or 1))
    local starPrice = settings.cutting.starPrice[stars]

    if settings.ingots[item.name] then
        if item.metadata and item.metadata.stamped then return end
        return settings.prices[item.name] * crime.unstamped
    end

    if item.name == 'gunpowder' then return crime.gunpowder end
    if item.name == 'dynamite' or item.name == 'homemade_dynamite' then return crime.dynamite end
    if item.name == 'gold_nugget' then return settings.prices.gold_nugget * crime.valuables end
    if settings.gems[item.name] then return settings.gems[item.name].price * crime.valuables end
    if cutPrice[item.name] then return cutPrice[item.name] * starPrice * crime.valuables end
    if settings.jewelry[item.name] then return settings.jewelry[item.name].price * starPrice * crime.valuables end
end

lib.callback.register('city_mining:crimeSell', function(source)
    if not Config.Features.crime then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not current or not util.near(src, current, crime.range) then return false, 'too_far' end

    local total, sold, taken = 0, 0, {}

    for _, item in pairs(exports.city_inventory:GetInventoryItems(src) or {}) do
        local unit = unitPrice(item)

        if unit and unit > 0 and exports.city_inventory:RemoveItem(src, item.name, item.count, item.metadata, item.slot) then
            taken[#taken + 1] = item
            total = total + unit * item.count
            sold = sold + item.count
        end
    end

    if sold == 0 then return false, 'nothing_to_sell' end

    total = math.floor(total)
    if not exports.qbx_core:AddMoney(src, 'cash', total, 'mining-crime') then
        lib.print.error(('city_mining: the crime buyer paying %s to %s was refused by city_economy'):format(total, citizenid))

        for _, item in ipairs(taken) do exports.city_inventory:AddItem(src, item.name, item.count, item.metadata) end

        return false, 'payment_failed'
    end

    return true, { sold = sold, total = total }
end)

publish()

CreateThread(function()
    while true do
        Wait(60000)
        publish()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then GlobalState.miningBuyer = nil end
end)
