-- Zip ties and the head bag: items anyone can use on a player who has given up (hands up, cuffed or down). Zip ties
-- are cuffs (metadata.ishandcuffed, through SetCuffed) marked with the zipTied state bag, cut with a blade; the head bag
-- is the headBag state bag, taken off by anyone close or falling off by itself.

local police = require 'server.police'
local settings = require 'server.config'

local ITEMS = Config.Restraints
local REACH = Config.Ranges.cuff

---@param target integer
---@return boolean
local function gaveUp(target)
    return police.restrained(target) or Player(target).state.handsup == true
end

---@param src integer
---@return integer? target
local function victimOf(src)
    if police.restrained(src) then return end

    local target = police.closest(src, REACH)
    if not target then
        police.notify(src, 'error_no_one_near', 'error')
        return
    end

    if GetVehiclePedIsIn(GetPlayerPed(target), false) ~= 0 then
        police.notify(src, 'error_in_vehicle', 'error')
        return
    end

    if not gaveUp(target) then
        police.notify(src, 'error_not_given_up', 'error')
        return
    end

    return target
end

exports.qbx_core:CreateUseableItem(ITEMS.zipTies, function(source)
    local src = source
    local target = victimOf(src)
    if not target then return end

    if exports.city_police:IsCuffed(target) then return police.notify(src, 'error_already_tied', 'error') end
    if not exports.city_inventory:RemoveItem(src, ITEMS.zipTies, 1) then return end

    exports.city_police:SetCuffed(target, true)
    Player(target).state:set('zipTied', true, true)
    police.notify(src, 'zip_tied_them', 'success')
end)

lib.callback.register('city_police:cutZipTies', function(source, target)
    local src = source
    if police.restrained(src) then return false end

    target = police.reach(src, target, REACH)
    if not target then return false, 'too_far' end
    if not Player(target).state.zipTied then return false, 'not_tied' end

    local hasBlade = false
    for _, name in ipairs(settings.zipCutters) do
        if exports.city_inventory:GetItemCount(src, name) > 0 then
            hasBlade = true
            break
        end
    end
    if not hasBlade then return false, 'no_blade' end

    exports.city_police:SetCuffed(target, false)

    return true
end)

---@param target integer
---@param on boolean
local function setBag(target, on)
    Player(target).state:set('headBag', on and os.time() or nil, true)
end

exports.qbx_core:CreateUseableItem(ITEMS.headBag, function(source)
    local src = source
    local target = victimOf(src)
    if not target then return end

    if Player(target).state.headBag then return police.notify(src, 'error_already_bagged', 'error') end
    if not exports.city_inventory:RemoveItem(src, ITEMS.headBag, 1) then return end

    setBag(target, true)
    police.notify(src, 'bagged_them', 'success')
end)

lib.callback.register('city_police:removeHeadBag', function(source, target)
    local src = source
    if police.restrained(src) then return false end

    target = police.reach(src, target, REACH)
    if not target then return false, 'too_far' end
    if not Player(target).state.headBag then return false, 'not_bagged' end

    setBag(target, false)
    exports.city_inventory:AddItem(src, ITEMS.headBag, 1)

    return true
end)

-- A forgotten bag falls off by itself
CreateThread(function()
    while true do
        Wait(60000)

        local limit = os.time() - settings.headBagMinutes * 60

        for target in pairs(exports.qbx_core:GetQBPlayers()) do
            local since = Player(target).state.headBag
            if type(since) == 'number' and since < limit then setBag(target, false) end
        end
    end
end)
