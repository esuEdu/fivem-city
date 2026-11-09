-- Labs: a door outside (the server says who may go in), a door inside, and one ox_target zone per recipe station
local util = require 'client.util'

local FADE_MS = 500

local zones = {}

---Fades out, moves the player, and fades back in once the interior around them has loaded
---@param coords vector4
local function teleport(coords)
    DoScreenFadeOut(FADE_MS)
    while not IsScreenFadedOut() do Wait(0) end

    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(cache.ped, coords.w)

    local interior = GetInteriorAtCoords(coords.x, coords.y, coords.z)

    if interior ~= 0 then
        local timeout = GetGameTimer() + 5000
        while not IsInteriorReady(interior) and GetGameTimer() < timeout do Wait(50) end
    end

    DoScreenFadeIn(FADE_MS)
end

local function enter(labId)
    local ok, reason = lib.callback.await('city_drugs:enterLab', false, labId)
    if not ok then return exports.qbx_core:Notify(locale(('error_%s'):format(reason or 'failed')), 'error') end

    teleport(Config.Labs[labId].exit)
end

local function batch(labId, index)
    local recipe = Config.Labs[labId].recipes[index]

    local ok = util.timed('city_drugs:startBatch', 'city_drugs:batch', { labId, index }, {
        seconds = recipe.seconds,
        label = locale('working'),
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
    })

    if ok then exports.qbx_core:Notify(locale('made', recipe.label), 'success') end
end

---"4x Cannabis Bud" lines for the option's description
local function describe(items)
    local parts = {}

    for item, count in pairs(items) do parts[#parts + 1] = ('%dx %s'):format(count, util.label(item)) end
    table.sort(parts)

    return table.concat(parts, ', ')
end

local function canUse()
    return not cache.vehicle and not util.busy()
end

local function door(coords, name, label, icon, onSelect)
    zones[#zones + 1] = exports.ox_target:addSphereZone({
        coords = coords.xyz,
        radius = Config.StationRadius,
        options = {
            { name = name, label = label, icon = icon, distance = Config.UseDistance, canInteract = canUse, onSelect = onSelect },
        },
    })
end

local function addLabs()
    for labId, lab in pairs(Config.Labs) do
        door(lab.entrance, ('city_drugs:enter:%s'):format(labId), locale('target_enter', lab.label), 'fas fa-door-open', function() enter(labId) end)
        door(lab.exit, ('city_drugs:exit:%s'):format(labId), locale('target_exit'), 'fas fa-door-closed', function() teleport(lab.entrance) end)

        for index, recipe in ipairs(lab.recipes) do
            zones[#zones + 1] = exports.ox_target:addSphereZone({
                coords = recipe.coords,
                radius = Config.StationRadius,
                options = {
                    {
                        name = ('city_drugs:lab:%s:%d'):format(labId, index),
                        label = locale('target_recipe', recipe.label, describe(recipe.inputs), describe(recipe.outputs)),
                        icon = 'fas fa-flask',
                        distance = Config.UseDistance,
                        canInteract = canUse,
                        onSelect = function() batch(labId, index) end,
                    },
                },
            })
        end
    end
end

-- city_inventory's item list has to be there for the labels
CreateThread(function()
    while GetResourceState('city_inventory') ~= 'started' do Wait(500) end
    addLabs()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for i = 1, #zones do exports.ox_target:removeZone(zones[i]) end
    if IsScreenFadedOut() then DoScreenFadeIn(0) end
end)
