-- The radio list: shown while this player is in a pma-voice radio channel, with who is in it and who is talking.
-- pma-voice's own events say who joins, leaves and talks; the names come from the server (callsign + name).
-- /radiolist hides or shows it, /radiolistmove frees the mouse to drag and resize it (saved in this computer's KVP).
lib.locale()

local theme = require '@city_ui.theme'

local KVP = 'city_radio:list'

local channel = 0
local members = {} ---@type table<integer, boolean> server id -> talking
local names = {} ---@type table<integer, string>
local selfTalking = false
local editing = false
local namesPending = false

---@return { hidden: boolean, x: number?, y: number?, width: number }
local function loadLayout()
    local saved = GetResourceKvpString(KVP)
    local ok, layout = pcall(json.decode, saved or '')
    layout = ok and type(layout) == 'table' and layout or {}

    return {
        hidden = layout.hidden == true,
        x = tonumber(layout.x),
        y = tonumber(layout.y),
        width = math.max(Config.Width.min, math.min(Config.Width.max, tonumber(layout.width) or Config.Width.default)),
    }
end

local layout = loadLayout()

local function saveLayout()
    SetResourceKvp(KVP, json.encode(layout))
end

local function draw()
    local list = {}

    for id, talking in pairs(members) do
        list[#list + 1] = { id = id, name = names[id] or ('#%d'):format(id), talking = id == cache.serverId and selfTalking or talking, me = id == cache.serverId }
    end

    table.sort(list, function(a, b) return a.name < b.name end)

    SendNUIMessage({
        action = 'list',
        theme = theme,
        visible = channel > 0 and not layout.hidden,
        editing = editing,
        layout = layout,
        widthRange = Config.Width,
        channel = channel,
        channelName = Config.ChannelNames[math.floor(channel)],
        members = list,
        labels = { title = locale('title'), live = locale('live'), channel = locale('channel'), members = locale('members'), done = locale('done'), tx = locale('tx') },
    })
end

-- Names of the members we don't know yet, asked once things settle
local function fetchNames()
    if namesPending then return end
    namesPending = true

    SetTimeout(600, function()
        namesPending = false

        local missing = {}
        for id in pairs(members) do
            if not names[id] then missing[#missing + 1] = id end
        end
        if #missing == 0 or channel <= 0 then return end

        local result = lib.callback.await('city_radio:names', false, missing) or {}
        for key, name in pairs(result) do names[tonumber(key)] = name end

        draw()
    end)
end

RegisterNetEvent('pma-voice:syncRadioData', function(radioTable)
    members = {}
    for id, talking in pairs(type(radioTable) == 'table' and radioTable or {}) do members[tonumber(id)] = talking == true end
    members[cache.serverId] = members[cache.serverId] or false

    draw()
    fetchNames()
end)

RegisterNetEvent('pma-voice:addPlayerToRadio', function(id)
    id = tonumber(id)
    if not id then return end

    members[id] = false
    draw()
    fetchNames()
end)

RegisterNetEvent('pma-voice:removePlayerFromRadio', function(id)
    id = tonumber(id)
    if not id then return end

    if id == cache.serverId then
        members, names = {}, {}
    else
        members[id] = nil
    end

    draw()
end)

RegisterNetEvent('pma-voice:setTalkingOnRadio', function(id, talking)
    id = tonumber(id)
    if not id or members[id] == nil then return end

    members[id] = talking == true
    draw()
end)

-- Our own transmit key (pma-voice fires this on the client)
AddEventHandler('pma-voice:radioActive', function(active)
    selfTalking = active == true
    draw()
end)

AddStateBagChangeHandler('radioChannel', ('player:%s'):format(cache.serverId), function(_, _, value)
    channel = tonumber(value) or 0
    if channel <= 0 then members, names = {}, {} end
    draw()
end)

local function stopEditing()
    if not editing then return end

    editing = false
    SetNuiFocus(false, false)
    saveLayout()
    draw()
end

RegisterCommand(Config.Commands.toggle, function()
    layout.hidden = not layout.hidden
    saveLayout()
    draw()
    lib.notify({ description = locale(layout.hidden and 'hidden' or 'shown'), type = 'inform' })
end, false)

RegisterCommand(Config.Commands.move, function()
    if channel <= 0 then return lib.notify({ description = locale('not_in_channel'), type = 'error' }) end
    if editing then return stopEditing() end

    editing = true
    layout.hidden = false
    SetNuiFocus(true, true)
    draw()
end, false)

RegisterKeyMapping(Config.Commands.toggle, locale('key_toggle'), 'keyboard', '')
TriggerEvent('chat:addSuggestion', ('/%s'):format(Config.Commands.toggle), locale('help_toggle'))
TriggerEvent('chat:addSuggestion', ('/%s'):format(Config.Commands.move), locale('help_move'))

-- The page sends where it was dragged and how wide it is
RegisterNUICallback('layout', function(data, cb)
    cb(1)
    if type(data) ~= 'table' then return end

    layout.x = tonumber(data.x)
    layout.y = tonumber(data.y)
    layout.width = math.max(Config.Width.min, math.min(Config.Width.max, tonumber(data.width) or layout.width))
end)

RegisterNUICallback('done', function(_, cb)
    cb(1)
    stopEditing()
end)

-- Started (or restarted) while already in a channel: ask who is in it
CreateThread(function()
    channel = tonumber(LocalPlayer.state.radioChannel) or 0

    if channel > 0 then
        for _, id in ipairs(lib.callback.await('city_radio:members', false) or {}) do members[id] = false end
        fetchNames()
    end

    draw()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    if editing then SetNuiFocus(false, false) end
    TriggerEvent('chat:removeSuggestion', ('/%s'):format(Config.Commands.toggle))
    TriggerEvent('chat:removeSuggestion', ('/%s'):format(Config.Commands.move))
end)
