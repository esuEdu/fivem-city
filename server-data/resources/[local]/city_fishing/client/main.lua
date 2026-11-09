-- The fishing shop, fish market and marina NPCs (spawned near the player), their blips and menus, and the
-- city-wide announcements (legendary catches, frenzies, tournaments).
local gear = require 'shared.gear'

local peds = {}
local points = {}
local blips = {}

---@param coords vector4
---@param options table[] ox_target options
---@return integer ped
local function spawnPed(coords, options)
    lib.requestModel(Config.Ped)

    local ped = CreatePed(4, Config.Ped, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    SetModelAsNoLongerNeeded(Config.Ped)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, Config.PedScenario, 0, true)
    exports.ox_target:addLocalEntity(ped, options)

    return ped
end

---@param key string
---@param coords vector4
---@param blip table
---@param label string
---@param options table[]
local function addPlace(key, coords, blip, label, options)
    local handle = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(handle, blip.sprite)
    SetBlipColour(handle, blip.color)
    SetBlipScale(handle, 0.7)
    SetBlipAsShortRange(handle, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(handle)
    blips[#blips + 1] = handle

    points[key] = lib.points.new({
        coords = coords.xyz,
        distance = Config.PedDistance,
        onEnter = function()
            if not peds[key] then peds[key] = spawnPed(coords, options) end
        end,
        onExit = function()
            local ped = peds[key]
            if not ped then return end

            exports.ox_target:removeLocalEntity(ped)
            DeleteEntity(ped)
            peds[key] = nil
        end,
    })
end

---@param ok boolean
---@param result any
---@param successKey string
---@param ... any
local function report(ok, result, successKey, ...)
    if ok then
        lib.notify({ description = locale(successKey, ...), type = 'success' })
    else
        lib.notify({ description = locale(result or 'invalid'), type = 'error' })
    end
end

local function itemLabel(name)
    local item = exports.city_inventory:Items(name)
    return item and item.label or name
end

---@param entry table gear.catalogue() entry
---@param info table shopInfo
local function buy(entry, info)
    local count = 1

    if entry.kind ~= 'rod' then
        local input = lib.inputDialog(itemLabel(entry.item), {
            { type = 'number', label = locale('shop_quantity'), default = 1, min = 1, max = entry.kind == 'bait' and 50 or 5, required = true },
        })
        if not input then return end
        count = math.floor(tonumber(input[1]) or 1)
    end

    local ok, result = lib.callback.await('city_fishing:buy', false, entry.item, count)
    report(ok, result, 'shop_bought', count, itemLabel(entry.item), result)
end

local openShop

---@param kind string
---@param info table
local function openKind(kind, info)
    local options = {}

    for _, entry in ipairs(gear.catalogue()) do
        if entry.kind == kind then
            local price = math.floor(entry.price * (1 - info.discount) + 0.5)
            local locked = info.level < entry.level

            options[#options + 1] = {
                title = itemLabel(entry.item),
                description = locked and locale('shop_needs_level', entry.level) or locale('shop_price', price),
                disabled = locked,
                onSelect = function() buy(entry, info) end,
            }
        end
    end

    lib.registerContext({ id = 'city_fishing_shop_kind', title = locale('shop_' .. kind), menu = 'city_fishing_shop', options = options })
    lib.showContext('city_fishing_shop_kind')
end

-- Menu options switched off by Config.Features are false; ox_lib needs a list without them
local function compact(list)
    local out = {}

    for _, option in ipairs(list) do
        if option then out[#out + 1] = option end
    end

    return out
end

openShop = function()
    local ok, info = lib.callback.await('city_fishing:shopInfo', false)
    if not ok then return end

    local licence = info.licence
    local licenceText = licence.valid and locale('licence_valid_until', licence.expiresText) or locale('licence_none')

    lib.registerContext({
        id = 'city_fishing_shop',
        title = locale('shop_title'),
        options = compact({
            {
                title = locale(licence.valid and 'shop_licence_extend' or 'shop_licence_buy'),
                description = ('%s · %s'):format(licenceText, locale('shop_price', licence.price)),
                icon = 'id-card',
                onSelect = function()
                    local bought, result = lib.callback.await('city_fishing:buyLicence', false)
                    report(bought, result, 'licence_bought')
                end,
            },
            { title = locale('shop_rod'), icon = 'fish', arrow = true, onSelect = function() openKind('rod', info) end },
            { title = locale('shop_bait'), icon = 'worm', arrow = true, onSelect = function() openKind('bait', info) end },
            Config.Features.tackle and { title = locale('shop_tackle'), icon = 'gear', arrow = true, onSelect = function() openKind('tackle', info) end },
            Config.Features.pots and { title = locale('shop_pot'), icon = 'box', arrow = true, onSelect = function() openKind('pot', info) end },
            {
                title = locale('shop_repair'),
                description = info.repair > 0 and locale('shop_price', info.repair) or locale('nothing_to_repair'),
                icon = 'wrench',
                disabled = info.repair == 0,
                onSelect = function()
                    local repaired, result = lib.callback.await('city_fishing:repair', false)
                    report(repaired, result, 'shop_repaired', result)
                end,
            },
            Config.Features.skills and {
                title = locale('shop_respec'),
                description = locale('shop_price', info.respec),
                icon = 'rotate-left',
                onSelect = function()
                    if lib.alertDialog({ header = locale('shop_respec'), content = locale('shop_respec_confirm', info.respec), cancel = true }) ~= 'confirm' then return end

                    local reset, result = lib.callback.await('city_fishing:respec', false)
                    report(reset, result, 'shop_respec_done')
                end,
            },
        }),
    })

    lib.showContext('city_fishing_shop')
end

local function sell()
    local ok, result = lib.callback.await('city_fishing:sell', false)

    if ok then
        lib.notify({ description = locale('sold', result.sold, result.total), type = 'success' })
    else
        lib.notify({ description = locale(result or 'invalid'), type = 'error' })
    end
end

local function marina()
    local ok, info = lib.callback.await('city_fishing:boatInfo', false)
    if not ok then return end

    lib.registerContext({
        id = 'city_fishing_marina',
        title = locale('marina_title'),
        options = {
            {
                title = locale('marina_rent'),
                description = locale('marina_rent_text', info.fee, info.deposit),
                icon = 'ship',
                disabled = info.renting,
                onSelect = function()
                    local rented, result = lib.callback.await('city_fishing:rentBoat', false)
                    report(rented, result, 'boat_rented')
                end,
            },
            {
                title = locale('marina_return'),
                icon = 'anchor',
                disabled = not info.renting,
                onSelect = function()
                    local returned, refunded = lib.callback.await('city_fishing:returnBoat', false)
                    if returned then
                        lib.notify({ description = locale(refunded and 'boat_returned' or 'boat_returned_lost'), type = 'success' })
                    else
                        lib.notify({ description = locale(refunded or 'invalid'), type = 'error' })
                    end
                end,
            },
        },
    })

    lib.showContext('city_fishing_marina')
end

for index, shop in ipairs(Config.Shops) do
    addPlace(('shop%d'):format(index), shop.coords, shop.blip, locale('blip_shop'), {
        { name = 'city_fishing:shop', icon = 'fa-solid fa-fish', label = locale('target_shop'), onSelect = openShop },
    })
end

for index, market in ipairs(Config.Markets) do
    addPlace(('market%d'):format(index), market.coords, market.blip, locale('blip_market'), {
        { name = 'city_fishing:sell', icon = 'fa-solid fa-sack-dollar', label = locale('target_sell'), onSelect = sell },
    })
end

for index, place in ipairs(Config.Features.boat and Config.Marinas or {}) do
    addPlace(('marina%d'):format(index), place.coords, place.blip, locale('blip_marina'), {
        { name = 'city_fishing:marina', icon = 'fa-solid fa-ship', label = locale('target_marina'), onSelect = marina },
    })
end

RegisterNetEvent('city_fishing:client:announce', function(key, ...)
    if GetInvokingResource() or type(key) ~= 'string' then return end

    lib.notify({ title = locale('announce_title'), description = locale(key, ...), type = 'inform', duration = 8000 })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for key, ped in pairs(peds) do
        exports.ox_target:removeLocalEntity(ped)
        DeleteEntity(ped)
        peds[key] = nil
    end

    for _, point in pairs(points) do point:remove() end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
end)
