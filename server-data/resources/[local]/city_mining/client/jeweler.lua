-- Vangelico: open geodes, cut rough gems, make jewellery, sell gems and jewellery. And the crime buyer, who moves
-- every day (GlobalState.miningBuyer).
local places = require 'client.places'

---@param seconds number
---@return string
local function minutesText(seconds)
    return ('%dm'):format(math.ceil(seconds / 60))
end

---@param result table
local function showDrops(result)
    local parts = {}
    for _, drop in ipairs(result.drops) do
        local stars = drop.metadata and drop.metadata.quality and (' ' .. string.rep('★', drop.metadata.quality)) or ''
        parts[#parts + 1] = ('%dx %s%s'):format(drop.count, places.label(drop.item), stars)
    end

    lib.notify({ description = locale('got_items', table.concat(parts, ', ')), type = 'success', duration = 7000 })
    if result.levelUp then lib.notify({ title = locale('level_up_title'), description = locale('level_up', result.levelUp), type = 'success' }) end
end

local openJeweler

local function openGeodes(info)
    local options = {}

    for _, geode in ipairs(info.geodes) do
        options[#options + 1] = {
            title = places.label(geode.name),
            description = locale('geode_text', geode.count, geode.fee),
            disabled = geode.count == 0,
            onSelect = function()
                if lib.progressBar({ duration = 3000, label = locale('opening_geode'), canCancel = false, disable = { move = true } }) then
                    local ok, result = lib.callback.await('city_mining:openGeode', false, geode.name)
                    if ok then showDrops(result) else lib.notify({ description = locale(result or 'invalid'), type = 'error' }) end
                end
                openJeweler()
            end,
        }
    end

    lib.registerContext({ id = 'city_mining_geodes', title = locale('jeweler_geodes'), menu = 'city_mining_jeweler', options = options })
    lib.showContext('city_mining_geodes')
end

local function openCutting(info)
    local options = {}

    for _, gem in ipairs(info.rough) do
        options[#options + 1] = {
            title = places.label(gem.name),
            description = locale('cut_text', gem.count, gem.fee, info.cutMinutes),
            disabled = info.order ~= nil,
            onSelect = function()
                local input = lib.inputDialog(places.label(gem.name), {
                    { type = 'number', label = locale('cut_count'), default = gem.count, min = 1, max = math.min(20, gem.count), required = true },
                })
                if not input then return end

                local ok, result = lib.callback.await('city_mining:cut', false, gem.name, math.floor(tonumber(input[1]) or 1))
                places.report(ok, result, 'order_placed', ok and minutesText(result) or nil)
            end,
        }
    end

    if #options == 0 then options[1] = { title = locale('no_rough_gems'), disabled = true } end

    lib.registerContext({ id = 'city_mining_cut', title = locale('jeweler_cut'), menu = 'city_mining_jeweler', options = options })
    lib.showContext('city_mining_cut')
end

local function openJewelry(info)
    local options = {}

    for _, piece in ipairs(info.jewelry) do
        local parts = {}
        for _, input in ipairs(piece.inputs) do parts[#parts + 1] = ('%dx %s'):format(input[2], places.label(input[1])) end

        options[#options + 1] = {
            title = places.label(piece.name),
            description = locale('craft_text', table.concat(parts, ' + '), info.craftFee, info.craftMinutes),
            disabled = info.order ~= nil,
            onSelect = function()
                local ok, result = lib.callback.await('city_mining:craft', false, piece.name)
                places.report(ok, result, 'order_placed', ok and minutesText(result) or nil)
            end,
        }
    end

    lib.registerContext({ id = 'city_mining_jewelry', title = locale('jeweler_craft'), menu = 'city_mining_jeweler', options = options })
    lib.showContext('city_mining_jewelry')
end

openJeweler = function()
    local ok, info = lib.callback.await('city_mining:jewelerInfo', false)
    if not ok then return end

    local options = {}

    if info.order then
        options[#options + 1] = {
            title = locale('jeweler_order'),
            description = info.order.secondsLeft > 0 and locale('order_ready_in', minutesText(info.order.secondsLeft)) or locale('order_ready'),
            icon = 'gem',
            disabled = info.order.secondsLeft > 0,
            onSelect = function()
                local collected, result = lib.callback.await('city_mining:jewelerCollect', false)
                if collected then showDrops(result) else lib.notify({ description = locale(result or 'invalid'), type = 'error' }) end
            end,
        }
    end

    options[#options + 1] = { title = locale('jeweler_geodes'), icon = 'egg', arrow = true, onSelect = function() openGeodes(info) end }
    options[#options + 1] = { title = locale('jeweler_cut'), icon = 'gem', arrow = true, onSelect = function() openCutting(info) end }
    options[#options + 1] = { title = locale('jeweler_craft'), icon = 'ring', arrow = true, onSelect = function() openJewelry(info) end }
    options[#options + 1] = {
        title = locale('jeweler_sell'),
        description = locale('jeweler_sell_text'),
        icon = 'sack-dollar',
        onSelect = function()
            if lib.alertDialog({ header = locale('jeweler_sell'), content = locale('jeweler_sell_confirm'), cancel = true }) ~= 'confirm' then return end

            local sold, result = lib.callback.await('city_mining:jewelerSell', false)
            if sold then
                lib.notify({ description = locale('sold', result.sold, result.total), type = 'success' })
            else
                lib.notify({ description = locale(result or 'invalid'), type = 'error' })
            end
        end,
    }

    lib.registerContext({ id = 'city_mining_jeweler', title = locale('jeweler_title'), options = options })
    lib.showContext('city_mining_jeweler')
end

places.blip(Config.Jeweler.coords, Config.Jeweler.blip, locale('blip_jeweler'))
places.add('jeweler', Config.JewelerPed, Config.Jeweler.coords, {
    { name = 'city_mining:jeweler', icon = 'fa-solid fa-gem', label = locale('target_jeweler'), onSelect = openJeweler },
})

-- The crime buyer
local function crimeSell()
    if lib.alertDialog({ header = locale('crime_title'), content = locale('crime_confirm'), cancel = true }) ~= 'confirm' then return end

    local ok, result = lib.callback.await('city_mining:crimeSell', false)
    if ok then
        lib.notify({ description = locale('sold', result.sold, result.total), type = 'success' })
    else
        lib.notify({ description = locale(result or 'invalid'), type = 'error' })
    end
end

---@param point table?
local function placeBuyer(point)
    places.remove('crime')
    if type(point) ~= 'table' then return end

    places.add('crime', Config.BuyerPed, vec4(point.x, point.y, point.z, point.w), {
        { name = 'city_mining:crime', icon = 'fa-solid fa-handshake', label = locale('target_crime'), onSelect = crimeSell },
    })
end

AddStateBagChangeHandler('miningBuyer', 'global', function(_, _, value)
    placeBuyer(value)
end)

CreateThread(function()
    placeBuyer(GlobalState.miningBuyer)
end)
