-- Phone notifications (a banner, then kept on the lock screen) and live activities in the dynamic island (a call in
-- progress, a timer). Silent mode mutes the sound; Do Not Disturb also hides the banner.
local nextId = 0
---@type table<integer, { event: string, data: any }>
local actions = {}

local function settings()
    return exports[cache.resource]:GetSettings() or {}
end

---@param data { app?: string, title: string, text?: string, icon?: string, action?: { event: string, data: any, label?: string }, force?: boolean }
-- force: show the banner even in Do Not Disturb (an incoming call)
local function notify(data)
    if type(data) ~= 'table' or type(data.title) ~= 'string' then return end

    nextId = nextId + 1

    if type(data.action) == 'table' and type(data.action.event) == 'string' then
        actions[nextId] = data.action
    end

    local current = settings()

    SendNUIMessage({
        action = 'notify',
        notification = {
            id = nextId,
            app = data.app,
            title = data.title,
            text = data.text,
            icon = data.icon,
            hasAction = actions[nextId] ~= nil,
            actionLabel = actions[nextId] and type(data.action.label) == 'string' and data.action.label:sub(1, 20) or nil,
        },
        quiet = current.dnd == true and data.force ~= true,
    })

    if not current.silent and not current.dnd and data.sound ~= false then
        PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    end
end

exports('Notify', notify)

RegisterNetEvent('city_phone:client:notify', function(data)
    if GetInvokingResource() then return end
    notify(data)
end)

-- Tapping a notification's button (e.g. a mail's "set location")
RegisterNUICallback('notificationAction', function(data, cb)
    local action = actions[tonumber(data.id)]

    if action then
        actions[tonumber(data.id)] = nil
        TriggerEvent(action.event, action.data)
    end

    cb(action ~= nil)
end)

RegisterNUICallback('notificationDismissed', function(data, cb)
    actions[tonumber(data.id) or 0] = nil
    cb(true)
end)

---Shows (or updates) a live activity in the dynamic island; nil data removes it
---@param id string
---@param data? { icon?: string, text: string, detail?: string, color?: string }
exports('SetActivity', function(id, data)
    if type(id) ~= 'string' then return end
    SendNUIMessage({ action = 'activity', id = id, data = type(data) == 'table' and data or nil })
end)
