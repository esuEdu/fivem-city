-- The active frenzy as a radius blip on the map, from GlobalState.fishingFrenzy.
local area, icon

local function clear()
    if area then RemoveBlip(area) end
    if icon then RemoveBlip(icon) end
    area, icon = nil, nil
end

---@param frenzy table?
local function show(frenzy)
    clear()
    if type(frenzy) ~= 'table' or not frenzy.coords then return end

    local coords = frenzy.coords
    area = AddBlipForRadius(coords.x, coords.y, coords.z, frenzy.radius + 0.0)
    SetBlipColour(area, 3)
    SetBlipAlpha(area, 90)

    icon = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(icon, 68)
    SetBlipColour(icon, 3)
    SetBlipScale(icon, 0.9)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('blip_frenzy', frenzy.label))
    EndTextCommandSetBlipName(icon)
end

AddStateBagChangeHandler('fishingFrenzy', 'global', function(_, _, value)
    show(value)
end)

CreateThread(function()
    show(GlobalState.fishingFrenzy)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then clear() end
end)
