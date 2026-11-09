-- The mining shop at Davis Quartz (licences, tools, safety gear, repairs, skill reset) and the region blips.
local gear = require 'shared.gear'
local places = require 'client.places'

local function buy(entry)
    local ok, result = lib.callback.await('city_mining:buy', false, entry.item)
    places.report(ok, result, 'shop_bought', places.label(entry.item), result)
end

---@param kind string
---@param info table
local function openKind(kind, info)
    local options = {}

    for _, entry in ipairs(gear.catalogue()) do
        if entry.kind == kind or (kind == 'tools' and (entry.kind == 'pan' or entry.kind == 'sluice' or entry.kind == 'furnace')) then
            local locked = info.level < entry.level
            local description = locked and locale('shop_needs_level', entry.level) or locale('shop_price', entry.price)

            if entry.kind == 'sluice' and not info.golden then
                locked = true
                description = locale('needs_golden_pan')
            end

            options[#options + 1] = {
                title = places.label(entry.item),
                description = description,
                disabled = locked,
                onSelect = function() buy(entry) end,
            }
        end
    end

    lib.registerContext({ id = 'city_mining_shop_kind', title = locale('shop_' .. kind), menu = 'city_mining_shop', options = options })
    lib.showContext('city_mining_shop_kind')
end

-- Menu options switched off by Config.Features are false; ox_lib needs a list without them
local function compact(list)
    local out = {}

    for _, option in ipairs(list) do
        if option then out[#out + 1] = option end
    end

    return out
end

local function openShop()
    local ok, info = lib.callback.await('city_mining:shopInfo', false)
    if not ok then return end

    local licence = info.licence
    local explosives = info.explosives
    local explosivesText

    if not explosives.granted then
        explosivesText = locale('explosives_ask_police')
    elseif info.level < explosives.level then
        explosivesText = locale('shop_needs_level', explosives.level)
    else
        explosivesText = ('%s · %s'):format(explosives.valid and locale('licence_valid_until', explosives.expires) or locale('licence_none'), locale('shop_price', explosives.price))
    end

    lib.registerContext({
        id = 'city_mining_shop',
        title = locale('shop_title'),
        options = compact({
            {
                title = locale(licence.valid and 'shop_licence_extend' or 'shop_licence_buy'),
                description = ('%s · %s'):format(licence.valid and locale('licence_valid_until', licence.expires) or locale('licence_none'), locale('shop_price', licence.price)),
                icon = 'id-card',
                onSelect = function()
                    local bought, result = lib.callback.await('city_mining:buyLicence', false)
                    places.report(bought, result, 'licence_bought')
                end,
            },
            Config.Features.dynamite and {
                title = locale('shop_explosives'),
                description = explosivesText,
                icon = 'bomb',
                disabled = not explosives.granted or info.level < explosives.level,
                onSelect = function()
                    local bought, result = lib.callback.await('city_mining:buyExplosives', false)
                    places.report(bought, result, 'licence_bought')
                end,
            },
            { title = locale('shop_pickaxe'), icon = 'hammer', arrow = true, onSelect = function() openKind('pickaxe', info) end },
            (Config.Features.panning or Config.Features.furnace) and { title = locale('shop_tools'), icon = 'toolbox', arrow = true, onSelect = function() openKind('tools', info) end },
            { title = locale('shop_ppe'), icon = 'helmet-safety', arrow = true, onSelect = function() openKind('ppe', info) end },
            {
                title = locale('shop_repair'),
                description = info.repair > 0 and locale('shop_price', info.repair) or locale('nothing_to_repair'),
                icon = 'wrench',
                disabled = info.repair == 0,
                onSelect = function()
                    local repaired, result = lib.callback.await('city_mining:repair', false)
                    places.report(repaired, result, 'shop_repaired', result)
                end,
            },
            Config.Features.skills and {
                title = locale('shop_respec'),
                description = locale('shop_price', info.respec),
                icon = 'rotate-left',
                onSelect = function()
                    if lib.alertDialog({ header = locale('shop_respec'), content = locale('shop_respec_confirm', info.respec), cancel = true }) ~= 'confirm' then return end

                    local reset, result = lib.callback.await('city_mining:respec', false)
                    places.report(reset, result, 'shop_respec_done')
                end,
            },
        }),
    })

    lib.showContext('city_mining_shop')
end

places.blip(Config.Shop.coords, Config.Shop.blip, locale('blip_shop'))
places.add('shop', Config.Ped, Config.Shop.coords, {
    { name = 'city_mining:shop', icon = 'fa-solid fa-helmet-safety', label = locale('target_shop'), onSelect = openShop },
})

-- Region blips, from the areas the server works out from the placed points
local regionBlips = {}

---@param areas table[]?
local function drawRegions(areas)
    for _, blip in ipairs(regionBlips) do RemoveBlip(blip) end
    regionBlips = {}

    for _, area in ipairs(areas or {}) do
        local blip = AddBlipForCoord(area.center.x, area.center.y, area.center.z)
        SetBlipSprite(blip, area.kind == 'gravel' and 365 or 618)
        SetBlipColour(blip, area.kind == 'gravel' and 3 or 5)
        SetBlipScale(blip, 0.65)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(area.label)
        EndTextCommandSetBlipName(blip)
        regionBlips[#regionBlips + 1] = blip
    end
end

AddStateBagChangeHandler('miningAreas', 'global', function(_, _, value)
    drawRegions(value)
end)

CreateThread(function()
    drawRegions(GlobalState.miningAreas)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, blip in ipairs(regionBlips) do RemoveBlip(blip) end
end)
