-- Vangelico: opens geodes (contents rolled here, when opened), cuts rough gems into 1-3 star gems (or breaks them),
-- makes jewellery from ingots and cut gems, and buys gems, jewellery and collectibles. Cutting and jewellery are
-- orders ready after a few minutes, made by an NPC for now (a jeweller job can take over later).
local settings = require 'server.config'
local profiles = require 'server.profiles'
local orders = require 'server.orders'
local rolls = require 'server.rolls'
local luck = require 'server.luck'
local util = require 'server.util'

local PLACE = 'jeweler'

-- Cut gem -> its rough gem's entry
local cutOf = {}
for rough, gem in pairs(settings.gems) do cutOf[gem.cut] = { rough = rough, price = gem.cutPrice } end

---@param src integer
---@return boolean
local function atJeweler(src)
    return util.near(src, Config.Jeweler.coords, settings.jeweler.range)
end

---@param metadata table?
---@return integer 1-3
local function starsOf(metadata)
    return math.max(1, math.min(3, math.tointeger(metadata and metadata.quality) or 1))
end

---@param stars integer
---@return table metadata for a cut gem or a piece of jewellery
local function starMetadata(stars)
    return { quality = stars, description = locale('stars_description', string.rep('★', stars)) }
end

---What Vangelico pays for one unit of an item, or nil if it doesn't buy it.
---@param item table slot
---@param profile table
---@return number?
local function unitPrice(item, profile)
    local gemBonus = 1 + profiles.skill(profile, 'gemologist')
    local starPrice = settings.cutting.starPrice[starsOf(item.metadata)]

    if settings.gems[item.name] then return settings.gems[item.name].price * gemBonus end
    if cutOf[item.name] then return cutOf[item.name].price * starPrice * gemBonus end
    if settings.jewelry[item.name] then return settings.jewelry[item.name].price * starPrice end

    return settings.collectibles[item.name]
end

local function profileCtx(profile)
    return { luck = luck.get(), skill = function(id) return profiles.skill(profile, id) end }
end

lib.callback.register('city_mining:jewelerInfo', function(source)
    if not Config.Features.jeweler then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player or not atJeweler(src) then return false end

    local geodes = {}
    for name, geode in pairs(settings.geodes) do
        geodes[#geodes + 1] = { name = name, fee = geode.fee, count = util.count(src, name) }
    end
    table.sort(geodes, function(a, b) return a.fee < b.fee end)

    local rough = {}
    for name, gem in pairs(settings.gems) do
        local count = util.count(src, name)
        if count > 0 then rough[#rough + 1] = { name = name, count = count, fee = math.floor(gem.cutPrice * settings.cutting.feeShare) } end
    end

    local jewelry = {}
    for name, piece in pairs(settings.jewelry) do
        jewelry[#jewelry + 1] = { name = name, inputs = piece.inputs, price = piece.price }
    end
    table.sort(jewelry, function(a, b) return a.price < b.price end)

    local order = orders.get(citizenid, PLACE)

    return true, {
        geodes = geodes,
        rough = rough,
        jewelry = jewelry,
        craftFee = settings.jewelryCraft.fee,
        cutMinutes = settings.cutting.minutes,
        craftMinutes = settings.jewelryCraft.minutes,
        order = order and { recipe = order.recipe, count = order.count, secondsLeft = math.max(0, order.ready_at - os.time()) } or nil,
    }
end)

lib.callback.register('city_mining:openGeode', function(source, name)
    if not Config.Features.jeweler then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not atJeweler(src) then return false, 'too_far' end

    local geode = type(name) == 'string' and settings.geodes[name]
    if not geode then return false, 'invalid' end
    if util.count(src, name) < 1 then return false, 'no_geode' end

    local profile = profiles.get(citizenid)
    local drop = rolls.geode(geode, profileCtx(profile), math.random)

    if not exports.city_inventory:CanCarryItem(src, drop.item, drop.count) then return false, 'inventory_full' end
    if not util.pay(src, geode.fee, 'mining-geode') then return false, 'no_money' end
    if not exports.city_inventory:RemoveItem(src, name, 1) then return false, 'no_geode' end

    exports.city_inventory:AddItem(src, drop.item, drop.count)
    local levelUp = profiles.addXp(profile, geode.xp)

    if drop.item == 'mountain_heart' then
        lib.print.info(('city_mining: %s found a Heart of the Mountain'):format(citizenid))
    end

    return true, { drops = { drop }, levelUp = levelUp }
end)

lib.callback.register('city_mining:cut', function(source, rough, count)
    if not Config.Features.jeweler then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not atJeweler(src) then return false, 'too_far' end

    local gem = type(rough) == 'string' and settings.gems[rough]
    count = math.tointeger(count)
    if not gem or not count or count < 1 or count > 20 then return false, 'invalid' end
    if orders.get(citizenid, PLACE) then return false, 'order_open' end
    if util.count(src, rough) < count then return false, 'missing_inputs' end

    local fee = math.floor(gem.cutPrice * settings.cutting.feeShare) * count
    if not util.pay(src, fee, 'mining-jeweler') then return false, 'no_money' end
    if not exports.city_inventory:RemoveItem(src, rough, count) then return false, 'missing_inputs' end

    orders.create(citizenid, PLACE, ('cut:%s'):format(rough), count, settings.cutting.minutes * 60)

    return true, settings.cutting.minutes * 60
end)

lib.callback.register('city_mining:craft', function(source, name)
    if not Config.Features.jeweler then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not atJeweler(src) then return false, 'too_far' end

    local piece = type(name) == 'string' and settings.jewelry[name]
    if not piece then return false, 'invalid' end
    if orders.get(citizenid, PLACE) then return false, 'order_open' end

    -- The gem's stars carry over: take the best one the player has
    local stars = 1
    if piece.gem then
        local best
        for _, slot in pairs(exports.city_inventory:GetSlotsWithItem(src, piece.gem) or {}) do
            if not best or starsOf(slot.metadata) > starsOf(best.metadata) then best = slot end
        end
        if not best then return false, 'missing_inputs' end
        stars = starsOf(best.metadata)

        for _, input in ipairs(piece.inputs) do
            if input[1] ~= piece.gem and util.countOf(src, input[1], settings.ingots[input[1]]) < input[2] then return false, 'missing_inputs' end
        end

        if not util.pay(src, settings.jewelryCraft.fee, 'mining-jeweler') then return false, 'no_money' end
        exports.city_inventory:RemoveItem(src, piece.gem, 1, nil, best.slot)

        local rest = {}
        for _, input in ipairs(piece.inputs) do
            if input[1] ~= piece.gem then rest[#rest + 1] = input end
        end
        util.takeAll(src, rest, settings.ingots)
    else
        for _, input in ipairs(piece.inputs) do
            if util.countOf(src, input[1], settings.ingots[input[1]]) < input[2] then return false, 'missing_inputs' end
        end

        if not util.pay(src, settings.jewelryCraft.fee, 'mining-jeweler') then return false, 'no_money' end
        util.takeAll(src, piece.inputs, settings.ingots)
    end

    orders.create(citizenid, PLACE, ('jewel:%s'):format(name), 1, settings.jewelryCraft.minutes * 60, { stars = stars })

    return true, settings.jewelryCraft.minutes * 60
end)

lib.callback.register('city_mining:jewelerCollect', function(source)
    if not Config.Features.jeweler then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not atJeweler(src) then return false, 'too_far' end

    local order = orders.get(citizenid, PLACE)
    if not order then return false, 'no_order' end
    if order.ready_at > os.time() then return false, 'not_ready' end

    local kind, name = order.recipe:match('^(%a+):(.+)$')
    local drops = {}

    if kind == 'cut' then
        local gem = settings.gems[name]
        if not gem then
            orders.close(order.id)
            return false, 'invalid'
        end

        local profile = profiles.get(citizenid)
        local gemologist = profiles.skill(profile, 'gemologist') > 0
        local byStars, broken = {}, 0

        for _ = 1, order.count do
            local stars = rolls.cut(settings.cutting, gemologist, luck.get(), math.random)
            if stars == 0 then broken = broken + 1 else byStars[stars] = (byStars[stars] or 0) + 1 end
        end

        for stars, count in pairs(byStars) do
            drops[#drops + 1] = { item = gem.cut, count = count, metadata = starMetadata(stars) }
        end

        if broken > 0 then drops[#drops + 1] = { item = settings.cutting.dust, count = broken } end
    elseif kind == 'jewel' and settings.jewelry[name] then
        drops[1] = { item = name, count = 1, metadata = starMetadata(math.tointeger(order.data.stars) or 1) }
    else
        orders.close(order.id)
        return false, 'invalid'
    end

    for _, drop in ipairs(drops) do
        if not exports.city_inventory:CanCarryItem(src, drop.item, drop.count, drop.metadata) then return false, 'inventory_full' end
    end

    if not orders.close(order.id) then return false, 'invalid' end
    util.giveAll(src, drops)

    return true, { drops = drops }
end)

lib.callback.register('city_mining:jewelerSell', function(source)
    if not Config.Features.jeweler then return false end
    local src = source
    local player, citizenid = util.player(src)
    if not player then return false end
    if not atJeweler(src) then return false, 'too_far' end

    local profile = profiles.get(citizenid)
    local total, sold, taken = 0, 0, {}

    for _, item in pairs(exports.city_inventory:GetInventoryItems(src) or {}) do
        local unit = unitPrice(item, profile)

        if unit and unit > 0 and exports.city_inventory:RemoveItem(src, item.name, item.count, item.metadata, item.slot) then
            taken[#taken + 1] = item
            total = total + unit * item.count
            sold = sold + item.count
        end
    end

    if sold == 0 then return false, 'nothing_to_sell' end

    total = math.floor(total)
    if not exports.qbx_core:AddMoney(src, 'cash', total, 'mining-jeweler-sell') then
        lib.print.error(('city_mining: Vangelico paying %s to %s was refused by city_economy'):format(total, citizenid))

        for _, item in ipairs(taken) do exports.city_inventory:AddItem(src, item.name, item.count, item.metadata) end

        return false, 'payment_failed'
    end

    return true, { sold = sold, total = total }
end)
