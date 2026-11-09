-- Breaking out (or in): hacking a gate terminal with a jammer or a trojan USB opens its gate for a while. The alarm
-- (GlobalState.prisonAlarm) sounds around the prison and the police get a call.

local settings = require 'server.config'
local util = require 'server.util'

local TERMINAL_RANGE = 2.0
local TOLERANCE_MS = 750

---@type table<integer, integer> gate index -> ox_doorlock id
local doors = {}
---@type table<integer, integer> terminal -> os.time() last hacked
local hackedAt = {}
---@type table<integer, { terminal: integer, at: integer }>
local hacking = {}

-- The gates are ox_doorlock doors (police can open them); created once by name if they are missing
CreateThread(function()
    while GetResourceState('ox_doorlock') ~= 'started' do Wait(500) end
    -- ox_doorlock reads its doors from the database on start
    Wait(5000)

    for index, gate in ipairs(Config.Gates) do
        local door = exports.ox_doorlock:getDoorFromName(gate.name)

        doors[index] = door and door.id or exports.ox_doorlock:createDoor({
            name = gate.name,
            model = gate.model,
            coords = gate.coords,
            heading = gate.heading,
            state = 1,
            maxDistance = 6.0,
            groups = { [Config.PoliceJob] = 0 },
        })
    end
end)

local function hasHackItem(src)
    for _, name in ipairs(settings.hack.items) do
        if exports.city_inventory:GetItemCount(src, name) > 0 then return name end
    end
end

local alarmToken = 0

local function alarm(coords)
    alarmToken = alarmToken + 1
    local token = alarmToken

    GlobalState.prisonAlarm = true
    SetTimeout(settings.hack.alarmSeconds * 1000, function()
        if alarmToken == token then GlobalState.prisonAlarm = false end
    end)

    if GetResourceState('city_police') ~= 'started' then return end

    exports.city_police:Alert({
        title = locale('alert_breakout_title'),
        text = locale('alert_breakout_text'),
        coords = coords,
        code = '10-98',
        priority = 2,
    })
end

local function openGate(index)
    local id = doors[index]
    if not id then return end

    exports.ox_doorlock:setDoorState(id, 0)

    SetTimeout(settings.hack.openSeconds * 1000, function()
        exports.ox_doorlock:setDoorState(id, 1)
    end)
end

lib.callback.register('city_prison:beginHack', function(source, index)
    local src = source
    if not Config.Features.escape then return false end
    local terminal = type(index) == 'number' and Config.Terminals[index]
    if not terminal or util.throttled(src, 'hack', 2) then return false end
    if not util.near(src, terminal.coords, TERMINAL_RANGE) then return false, 'too_far' end
    if not hasHackItem(src) then return false, 'no_item' end
    if hackedAt[index] and os.time() - hackedAt[index] < settings.hack.terminalCooldown then return false, 'cooldown' end
    if util.policeOnDuty() < settings.hack.minPolice then return false, 'no_police' end

    hacking[src] = { terminal = index, at = GetGameTimer() }

    return true, settings.hack.seconds
end)

lib.callback.register('city_prison:finishHack', function(source, index, success)
    local src = source
    if not Config.Features.escape then return false end
    local started = hacking[src]
    hacking[src] = nil

    if not started or started.terminal ~= index then return false end
    if GetGameTimer() - started.at < settings.hack.seconds * 1000 - TOLERANCE_MS then
        util.warn(src, 'finished a gate hack too early')
        return false
    end

    local terminal = Config.Terminals[index]
    if not util.near(src, terminal.coords, TERMINAL_RANGE) then return false, 'too_far' end

    local item = hasHackItem(src)
    if not item then return false, 'no_item' end

    -- The minigame runs on the client; a cheater only skips a skill check that the item and the alarm still pay for
    local outcome = success == true and 'success' or 'fail'

    if math.random(100) <= settings.hack.loseItem[outcome] then exports.city_inventory:RemoveItem(src, item, 1) end
    if math.random(100) <= settings.hack.alarm[outcome] then alarm(terminal.coords) end

    if outcome == 'fail' then return true, false end

    hackedAt[index] = os.time()
    openGate(terminal.gate)
    lib.print.info(('city_prison: %s hacked gate %s'):format(GetPlayerName(src), terminal.gate))

    return true, true
end)

AddEventHandler('playerDropped', function()
    hacking[source] = nil
end)
