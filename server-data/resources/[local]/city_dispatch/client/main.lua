-- Responders' side: a phone notification and a blip for each new call, and /calls with the open calls of their service
lib.locale()

local BLIP_MS = Config.ExpireMinutes * 60000

---@type table<integer, integer> call id -> blip
local blips = {}

---@param id integer
local function removeBlip(id)
    if blips[id] then RemoveBlip(blips[id]) end
    blips[id] = nil
end

---@param coords vector3 | { x: number, y: number, z: number }
---@return string
local function street(coords)
    return GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
end

---@param seconds integer
---@return string
local function ago(seconds)
    return ('%d min'):format(math.max(1, math.floor(seconds / 60)))
end

---@param id integer
local function respond(id)
    local coords = lib.callback.await('city_dispatch:respond', false, id)
    if not coords then return exports.qbx_core:Notify(locale('call_gone'), 'error') end

    SetNewWaypoint(coords.x, coords.y)
    exports.qbx_core:Notify(locale('responding'), 'success')
end

---@param call table
local function addBlip(call)
    local service = Config.Services[call.service]
    local blip = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)

    SetBlipSprite(blip, service.blip.sprite)
    SetBlipColour(blip, service.blip.colour)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s · %s'):format(service.number, call.kind))
    EndTextCommandSetBlipName(blip)

    blips[call.id] = blip
    SetTimeout(BLIP_MS, function() removeBlip(call.id) end)
end

RegisterNetEvent('city_dispatch:client:newCall', function(call)
    if GetInvokingResource() or type(call) ~= 'table' or not Config.Services[call.service] then return end

    addBlip(call)

    local text = ('%s · %s'):format(call.caller, street(call.coords))
    if call.text ~= '' then text = ('%s: %s'):format(text, call.text) end

    exports.city_phone:Notify({
        app = call.service,
        title = ('%s · %s'):format(Config.Services[call.service].number, call.kind),
        text = text,
        action = { event = 'city_dispatch:client:respond', data = call.id, label = locale('respond') },
    })
end)

-- The notification's Respond button
AddEventHandler('city_dispatch:client:respond', function(id)
    if math.type(id) == 'integer' then respond(id) end
end)

RegisterNetEvent('city_dispatch:client:closed', function(id)
    if GetInvokingResource() then return end
    removeBlip(id)
end)

---@param call table
local function openCall(call)
    local options = {
        { title = locale('menu_respond'), icon = 'location-dot', onSelect = function() respond(call.id) end },
    }

    if call.responding then
        options[#options + 1] = {
            title = locale('menu_close'),
            icon = 'circle-check',
            onSelect = function()
                if lib.callback.await('city_dispatch:close', false, call.id) then
                    exports.qbx_core:Notify(locale('call_closed'), 'success')
                end
            end,
        }
    end

    lib.registerContext({ id = 'city_dispatch_call', title = call.kind, menu = 'city_dispatch_calls', options = options })
    lib.showContext('city_dispatch_call')
end

local function openCalls()
    -- EMS keep using the hospital's list, where the SOS of downed players are too
    if QBX.PlayerData.job and QBX.PlayerData.job.type == Config.Services.ems.jobType then
        return ExecuteCommand('emscalls')
    end

    local list = lib.callback.await('city_dispatch:calls', false)
    if not list then return exports.qbx_core:Notify(locale('not_responder'), 'error') end
    if #list == 0 then return exports.qbx_core:Notify(locale('no_calls'), 'inform') end

    local options = {}

    for _, call in ipairs(list) do
        local description = locale('menu_desc', ago(call.ago), call.caller, street(call.coords))
        if call.text ~= '' then description = ('%s\n%s'):format(description, call.text) end
        if call.responders > 0 then description = ('%s\n%s'):format(description, locale('menu_responders', call.responders)) end

        options[#options + 1] = {
            title = call.kind,
            description = description,
            icon = call.responding and 'car-on' or 'bell',
            arrow = true,
            onSelect = function() openCall(call) end,
        }
    end

    lib.registerContext({ id = 'city_dispatch_calls', title = locale('menu_title', Config.Services[list[1].service].number), options = options })
    lib.showContext('city_dispatch_calls')
end

RegisterCommand('calls', openCalls, false)
TriggerEvent('chat:addSuggestion', '/calls', locale('command_help'))

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, blip in pairs(blips) do RemoveBlip(blip) end
end)
