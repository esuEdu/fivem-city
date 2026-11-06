-- Staff tools on themselves: noclip, invisible, godmode, names over heads, player blips. The server says yes first.

local state = { noclip = false, invisible = false, godmode = false, names = false, blips = false }

local selfTools = {}

---@type table<integer, integer> server id -> blip
local blips = {}

local function applyGodmode()
    SetPlayerInvincible(cache.playerId, state.godmode)
    SetEntityInvincible(cache.ped, state.godmode)
end

local function applyInvisible()
    SetEntityVisible(cache.ped, not state.invisible, false)
end

---@param entity integer
---@param on boolean
local function ghost(entity, on)
    FreezeEntityPosition(entity, on)
    SetEntityCollision(entity, not on, not on)
    SetEntityInvincible(entity, on or (entity == cache.ped and state.godmode))
    SetEntityVisible(entity, not on and not (entity == cache.ped and state.invisible), false)
end

local function noclipLoop()
    local speeds = Config.NoclipSpeeds
    local entity = cache.vehicle or cache.ped
    ghost(entity, true)

    while state.noclip do
        local current = cache.vehicle or cache.ped

        if current ~= entity then
            ghost(entity, false)
            entity = current
            ghost(entity, true)
        end

        -- Movement keys move the noclip instead of the ped
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 22, true)
        DisableControlAction(0, 36, true)
        DisableControlAction(0, 19, true)

        local speed = IsDisabledControlPressed(0, 21) and speeds.fast or IsDisabledControlPressed(0, 19) and speeds.slow or speeds.normal
        local rotation = GetGameplayCamRot(2)
        local heading, pitch = math.rad(rotation.z), math.rad(rotation.x)
        local forward = vector3(-math.sin(heading) * math.cos(pitch), math.cos(heading) * math.cos(pitch), math.sin(pitch))
        local right = vector3(math.cos(heading), math.sin(heading), 0.0)
        local move = vector3(0.0, 0.0, 0.0)

        if IsControlPressed(0, 32) then move = move + forward end
        if IsControlPressed(0, 33) then move = move - forward end
        if IsControlPressed(0, 34) then move = move - right end
        if IsControlPressed(0, 35) then move = move + right end
        if IsDisabledControlPressed(0, 22) then move = move + vector3(0.0, 0.0, 1.0) end
        if IsDisabledControlPressed(0, 36) then move = move - vector3(0.0, 0.0, 1.0) end

        local coords = GetEntityCoords(entity) + move * speed
        SetEntityCoordsNoOffset(entity, coords.x, coords.y, coords.z, true, true, true)
        SetEntityHeading(entity, rotation.z)
        SetEntityLocallyVisible(entity)

        Wait(0)
    end

    ghost(entity, false)
end

local function namesLoop()
    while state.names do
        local myCoords = GetEntityCoords(cache.ped)

        for _, player in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(player)
            local coords = GetEntityCoords(ped)

            if player ~= cache.playerId and #(coords - myCoords) < Config.NameDistance then
                local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z + 1.1)

                if onScreen then
                    SetTextScale(0.32, 0.32)
                    SetTextFont(4)
                    SetTextCentre(true)
                    SetTextOutline()
                    BeginTextCommandDisplayText('STRING')
                    AddTextComponentSubstringPlayerName(('[%d] %s'):format(GetPlayerServerId(player), GetPlayerName(player)))
                    EndTextCommandDisplayText(x, y)
                end
            end
        end

        Wait(0)
    end
end

local function clearBlips()
    for id, blip in pairs(blips) do
        RemoveBlip(blip)
        blips[id] = nil
    end
end

RegisterNetEvent('city_staff:client:blips', function(list)
    if GetInvokingResource() or not state.blips or type(list) ~= 'table' then return end

    local seen = {}

    for _, player in ipairs(list) do
        if player.id ~= cache.serverId then
            seen[player.id] = true
            local blip = blips[player.id]

            if not blip then
                blip = AddBlipForCoord(player.x, player.y, player.z)
                SetBlipSprite(blip, 1)
                SetBlipColour(blip, 0)
                SetBlipScale(blip, 0.8)
                SetBlipCategory(blip, 7)
                ShowHeadingIndicatorOnBlip(blip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(('[%d] %s'):format(player.id, player.name))
                EndTextCommandSetBlipName(blip)
                blips[player.id] = blip
            end

            SetBlipCoords(blip, player.x, player.y, player.z)
            SetBlipRotation(blip, math.floor(player.heading))
        end
    end

    for id, blip in pairs(blips) do
        if not seen[id] then
            RemoveBlip(blip)
            blips[id] = nil
        end
    end
end)

---@param tool string
---@return boolean
function selfTools.get(tool)
    return state[tool] == true
end

---@return table<string, boolean>
function selfTools.all()
    return state
end

---Turns a tool on or off on this client (after the server allowed it).
---@param tool string
---@param on boolean
function selfTools.set(tool, on)
    if state[tool] == nil or state[tool] == on then return end

    state[tool] = on

    if tool == 'noclip' and on then
        CreateThread(noclipLoop)
    elseif tool == 'names' and on then
        CreateThread(namesLoop)
    elseif tool == 'blips' and not on then
        clearBlips()
    elseif tool == 'godmode' then
        applyGodmode()
    elseif tool == 'invisible' then
        applyInvisible()
    end
end

-- Respawning gives a new ped without the state
lib.onCache('ped', function(ped)
    if not state.godmode and not state.invisible then return end

    SetTimeout(0, function()
        SetEntityInvincible(ped, state.godmode)
        SetPlayerInvincible(cache.playerId, state.godmode)
        SetEntityVisible(ped, not state.invisible, false)
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    clearBlips()
    if state.godmode then
        SetPlayerInvincible(cache.playerId, false)
        SetEntityInvincible(cache.ped, false)
    end

    if state.invisible then SetEntityVisible(cache.ped, true, false) end

    if state.noclip then
        local entity = cache.vehicle or cache.ped
        FreezeEntityPosition(entity, false)
        SetEntityCollision(entity, true, true)
        SetEntityVisible(entity, true, false)
    end
end)

return selfTools
