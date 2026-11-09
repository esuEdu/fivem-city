-- The public smelter (smelting orders, coal, dynamite, the ore buyer) and the home furnace menus. Both draw the same
-- recipe list; the server prices and checks everything.
local places = require 'client.places'

---@param inputs table[] { name, count }
---@return string
local function inputsText(inputs)
    local parts = {}
    for _, input in ipairs(inputs) do parts[#parts + 1] = ('%dx %s'):format(input[2], places.label(input[1])) end

    return table.concat(parts, ' + ')
end

---@param seconds number
---@return string
local function timeText(seconds)
    if seconds >= 3600 then return ('%dh %02dm'):format(math.floor(seconds / 3600), math.floor((seconds % 3600) / 60)) end
    if seconds >= 60 then return ('%dm %02ds'):format(math.floor(seconds / 60), seconds % 60) end

    return ('%ds'):format(seconds)
end

---@param order table?
---@param collect string callback name
---@return table? menu option
local function orderOption(order, collect)
    if not order then return end

    return {
        title = locale('order_title', order.count, places.label(order.recipe)),
        description = order.secondsLeft > 0 and locale('order_ready_in', timeText(order.secondsLeft)) or locale('order_ready'),
        icon = 'box',
        disabled = order.secondsLeft > 0,
        onSelect = function()
            local ok, result = lib.callback.await(collect, false)
            if ok then
                lib.notify({ description = locale('order_collected', result.drops[1].count, places.label(result.drops[1].item)), type = 'success' })
                if result.levelUp then lib.notify({ title = locale('level_up_title'), description = locale('level_up', result.levelUp), type = 'success' }) end
            else
                lib.notify({ description = locale(result or 'invalid'), type = 'error' })
            end
        end,
    }
end

---@param info table
---@param smeltCallback string
---@param menuId string
local function recipeOptions(info, smeltCallback, menuId)
    local options = {}

    for _, recipe in ipairs(info.recipes) do
        local parts = { inputsText(recipe.inputs), timeText(recipe.seconds) }
        if recipe.fee and recipe.fee > 0 then parts[#parts + 1] = locale('shop_price', recipe.fee) end

        options[#options + 1] = {
            title = places.label(recipe.name),
            description = locale('recipe_each', table.concat(parts, ' · ')),
            disabled = info.order ~= nil,
            onSelect = function()
                local input = lib.inputDialog(places.label(recipe.name), {
                    { type = 'number', label = locale('smelt_count'), default = 1, min = 1, max = info.maxBatch, required = true },
                })
                if not input then return end

                local ok, result = lib.callback.await(smeltCallback, false, recipe.name, math.floor(tonumber(input[1]) or 1))
                places.report(ok, result, 'smelt_started', ok and timeText(result) or nil)
            end,
        }
    end

    lib.registerContext({ id = menuId .. '_recipes', title = locale('smelt_title'), menu = menuId, options = options })
    lib.showContext(menuId .. '_recipes')
end

local function sell()
    local ok, result = lib.callback.await('city_mining:sell', false)

    if ok then
        lib.notify({ description = locale('sold', result.sold, result.total), type = 'success' })
    else
        lib.notify({ description = locale(result or 'invalid'), type = 'error' })
    end
end

---@param callback string
---@param title string
---@param max integer
local function buyCount(callback, title, max)
    local input = lib.inputDialog(title, {
        { type = 'number', label = locale('shop_quantity'), default = 1, min = 1, max = max, required = true },
    })
    if not input then return end

    local ok, result = lib.callback.await(callback, false, math.floor(tonumber(input[1]) or 1))
    places.report(ok, result, 'shop_paid', result)
end

local function openSmelter()
    local ok, info = lib.callback.await('city_mining:smelterInfo', false)
    if not ok then return end

    local options = {}
    local order = orderOption(info.order, 'city_mining:collect')
    if order then options[#options + 1] = order end

    options[#options + 1] = {
        title = locale('smelt_title'),
        description = info.licence and (info.order and locale('order_open') or locale('smelt_text')) or locale('no_licence'),
        icon = 'fire',
        arrow = true,
        disabled = not info.licence,
        onSelect = function() recipeOptions(info, 'city_mining:smelt', 'city_mining_smelter') end,
    }
    options[#options + 1] = {
        title = locale('buy_coal'),
        description = locale('shop_price', info.coal),
        icon = 'cube',
        onSelect = function() buyCount('city_mining:buyCoal', places.label('coal'), 100) end,
    }
    options[#options + 1] = Config.Features.dynamite and {
        title = locale('buy_dynamite'),
        description = info.dynamite.allowed and locale('dynamite_left', info.dynamite.left, info.dynamite.price) or locale('no_explosives_licence'),
        icon = 'bomb',
        disabled = not info.dynamite.allowed or info.dynamite.left == 0,
        onSelect = function() buyCount('city_mining:buyDynamite', places.label('dynamite'), info.dynamite.left) end,
    } or nil

    lib.registerContext({ id = 'city_mining_smelter', title = locale('smelter_title'), options = options })
    lib.showContext('city_mining_smelter')
end

places.blip(Config.Smelter.coords, Config.Smelter.blip, locale('blip_smelter'))
places.add('smelter', Config.Ped, Config.Smelter.coords, {
    { name = 'city_mining:smelter', icon = 'fa-solid fa-fire', label = locale('target_smelter'), onSelect = openSmelter },
    { name = 'city_mining:sell', icon = 'fa-solid fa-sack-dollar', label = locale('target_sell'), onSelect = sell },
})

-- Home furnace: drawn when the player is inside a property that has one
local furnace

local function openFurnace()
    local ok, info = lib.callback.await('city_mining:furnaceInfo', false)
    if not ok then return lib.notify({ description = locale(info or 'invalid'), type = 'error' }) end

    local options = {}
    local order = orderOption(info.order, 'city_mining:furnaceCollect')
    if order then options[#options + 1] = order end

    options[#options + 1] = {
        title = locale('smelt_title'),
        description = info.order and locale('order_open') or locale('furnace_text'),
        icon = 'fire',
        arrow = true,
        onSelect = function() recipeOptions(info, 'city_mining:furnaceSmelt', 'city_mining_furnace') end,
    }

    if info.owner then
        options[#options + 1] = {
            title = locale('furnace_pick_up'),
            icon = 'hand',
            disabled = info.order ~= nil,
            onSelect = function()
                local picked, result = lib.callback.await('city_mining:furnacePickUp', false)
                places.report(picked, result, 'furnace_picked_up')
            end,
        }
    end

    lib.registerContext({ id = 'city_mining_furnace', title = places.label('home_furnace'), options = options })
    lib.showContext('city_mining_furnace')
end

local function removeFurnace()
    if furnace and DoesEntityExist(furnace) then
        exports.ox_target:removeLocalEntity(furnace)
        DeleteEntity(furnace)
    end

    furnace = nil
end

local function refreshFurnace()
    removeFurnace()

    local playerData = exports.qbx_core:GetPlayerData()
    if not playerData or not playerData.metadata or not playerData.metadata.currentPropertyId then return end

    local ok, at = lib.callback.await('city_mining:furnaceHere', false)
    if not ok then return end

    local model = `prop_ind_mech_02a`
    if not IsModelInCdimage(model) then model = `prop_bbq_5` end
    lib.requestModel(model)
    furnace = CreateObject(model, at.x, at.y, at.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityHeading(furnace, at.h)
    FreezeEntityPosition(furnace, true)
    exports.ox_target:addLocalEntity(furnace, {
        { name = 'city_mining:furnace', icon = 'fa-solid fa-fire', label = locale('target_furnace'), onSelect = openFurnace },
    })
end

RegisterNetEvent('city_mining:client:furnaceChanged', function()
    if GetInvokingResource() then return end
    refreshFurnace()
end)

local lastProperty

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    local property = data and data.metadata and data.metadata.currentPropertyId
    if property == lastProperty then return end

    lastProperty = property
    SetTimeout(1500, refreshFurnace)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then removeFurnace() end
end)
