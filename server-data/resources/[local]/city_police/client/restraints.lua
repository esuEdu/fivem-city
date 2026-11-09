-- Zip ties and the head bag. Using the items is server-side (closest player); this adds the ox_target options to
-- undo them and plays the bag for the player wearing it: a black screen and a bag on the head.

local job = require 'client.job'

local REACH = Config.Ranges.cuff
local BAG_MODEL = Config.Restraints.headBagProp
local HEAD_BONE = 12844

---@param entity integer ped
---@param key string
---@return boolean
local function stateOf(entity, key)
    local target = job.serverIdOf(entity)

    return target > 0 and Player(target).state[key] ~= nil
end

---@param action string city_police callback
---@param entity integer
local function undo(action, entity)
    local ok, reason = lib.callback.await(action, false, job.serverIdOf(entity))
    if not ok then return job.fail(reason) end
end

exports.ox_target:addGlobalPlayer({
    {
        name = 'city_police:cutZipTies', label = locale('target_cut_zip_ties'), icon = 'fas fa-scissors', distance = REACH,
        canInteract = function(entity) return stateOf(entity, 'zipTied') end,
        onSelect = function(data) undo('city_police:cutZipTies', data.entity) end,
    },
    {
        name = 'city_police:removeHeadBag', label = locale('target_remove_head_bag'), icon = 'fas fa-mask', distance = REACH,
        canInteract = function(entity) return stateOf(entity, 'headBag') end,
        onSelect = function(data) undo('city_police:removeHeadBag', data.entity) end,
    },
})

local bagObject = nil

---@param on boolean
local function wearBag(on)
    SendNUIMessage({ action = 'headBag', on = on })

    if bagObject then
        DeleteEntity(bagObject)
        bagObject = nil
    end

    if not on then return end

    lib.requestModel(BAG_MODEL)
    bagObject = CreateObject(BAG_MODEL, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(bagObject, cache.ped, GetPedBoneIndex(cache.ped, HEAD_BONE), 0.2, 0.04, 0.0, 0.0, 270.0, 60.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(BAG_MODEL)
end

AddStateBagChangeHandler('headBag', ('player:%s'):format(cache.serverId), function(_, _, value)
    wearBag(value ~= nil)
end)

CreateThread(function()
    if LocalPlayer.state.headBag then wearBag(true) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    exports.ox_target:removeGlobalPlayer({ 'city_police:cutZipTies', 'city_police:removeHeadBag' })
    if bagObject then DeleteEntity(bagObject) end
end)
