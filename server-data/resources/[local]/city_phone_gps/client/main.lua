-- Adds the Maps app to city_phone. Opening it (or its Open Map button) puts the phone away and opens the game's own
-- map, where the route is set and the player's position moves; closing the map brings the phone back.
local APP = 'gps'
local MAP_OPEN_TIMEOUT = 2000

local opening = false

local function register()
    exports.city_phone:RegisterApp({
        id = APP,
        label = 'Maps',
        labels = { ['pt-br'] = 'Mapas' },
        icon = 'web/icon.svg',
        color = '#0a84ff',
        page = 'web/index.html',
        order = 20,
    })
end

-- city_phone may start after us, or restart
CreateThread(function()
    while GetResourceState('city_phone') ~= 'started' do Wait(500) end
    register()
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'city_phone' then register() end
end)

---@return vector3?
local function routeCoords()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return end

    return GetBlipInfoIdCoord(blip)
end

local function openMap()
    if opening or IsPauseMenuActive() then return end

    opening = true
    exports.city_phone:Close()

    CreateThread(function()
        -- the phone lets go of the mouse first
        Wait(150)
        ActivateFrontendMenu(`FE_MENU_VERSION_MP_PAUSE`, false, -1)
        Wait(100)
        PauseMenuceptionGoDeeper(0)

        local waited = 0
        while not IsPauseMenuActive() and waited < MAP_OPEN_TIMEOUT do
            Wait(50)
            waited = waited + 50
        end

        while IsPauseMenuActive() do Wait(250) end

        opening = false
        exports.city_phone:Open()
        exports.city_phone:SendAppMessage(APP, { action = 'refresh' })
    end)
end

-- Launching the app from the home screen goes straight to the map
AddEventHandler('city_phone:client:appOpened', function(id)
    if id == APP then openMap() end
end)

RegisterNUICallback('open', function(_, cb)
    openMap()
    cb(true)
end)

RegisterNUICallback('status', function(_, cb)
    local coords = routeCoords()
    if not coords then return cb({}) end

    cb({
        street = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z)),
        zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)),
        distance = math.floor(#(GetEntityCoords(cache.ped).xy - coords.xy)),
    })
end)

RegisterNUICallback('clear', function(_, cb)
    SetWaypointOff()
    cb(true)
end)
