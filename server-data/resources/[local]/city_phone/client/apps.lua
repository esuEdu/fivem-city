-- Apps other resources add to the phone. Each app is its own resource with its own page; the phone shows that page in
-- a frame and passes messages both ways.
--
--   exports.city_phone:RegisterApp({
--       id = 'calls', label = 'Phone', labels = { ['pt-br'] = 'Telefone' },
--       icon = 'web/icon.svg', color = '#34c759', page = 'web/index.html', dock = true, order = 1,
--   })
--   exports.city_phone:SendAppMessage('calls', { action = 'incoming', number = '555' })
--
-- The app's page talks to its own resource with fetch('https://<resource>/<callback>') as usual.
local apps = {}

---@type table<string, table>
local registered = {}

local function send(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

---@return table[]
function apps.list()
    local list = {}

    for _, app in pairs(registered) do list[#list + 1] = app end
    table.sort(list, function(a, b) return a.order < b.order end)

    return list
end

local function url(resource, path)
    if type(path) ~= 'string' then return nil end
    if path:find('^https?://') then return path end

    return ('https://cfx-nui-%s/%s'):format(resource, path)
end

exports('RegisterApp', function(data)
    local resource = GetInvokingResource() or cache.resource

    if type(data) ~= 'table' or type(data.id) ~= 'string' or type(data.label) ~= 'string' or type(data.page) ~= 'string' then
        return lib.print.warn(('city_phone: invalid app from %s'):format(resource))
    end

    registered[data.id] = {
        id = data.id,
        resource = resource,
        label = data.label,
        labels = type(data.labels) == 'table' and data.labels or {},
        icon = url(resource, data.icon),
        color = type(data.color) == 'string' and data.color or '#8e8e93',
        page = url(resource, data.page),
        dock = data.dock == true,
        order = tonumber(data.order) or 100,
    }

    send('apps', { apps = apps.list() })
end)

exports('RemoveApp', function(id)
    registered[id] = nil
    send('apps', { apps = apps.list() })
end)

---Sends data to an app's page (it receives { type = 'city_phone:message', data = ... })
exports('SendAppMessage', function(id, data)
    if not registered[id] then return end
    send('appMessage', { app = id, data = data })
end)

---Switches the phone to an app (shown now if it is open, or the next time it opens)
exports('OpenApp', function(id)
    if not registered[id] then return end
    send('openApp', { app = id })
end)

-- Opening and closing an app, so its resource can start or stop what it needs
RegisterNUICallback('appState', function(data, cb)
    if type(data.app) == 'string' and registered[data.app] then
        TriggerEvent(('city_phone:client:app%s'):format(data.open and 'Opened' or 'Closed'), data.app)
    end

    cb(true)
end)

-- An app's resource stopping takes the app off the phone
AddEventHandler('onClientResourceStop', function(resource)
    local changed = false

    for id, app in pairs(registered) do
        if app.resource == resource then
            registered[id] = nil
            changed = true
        end
    end

    if changed then send('apps', { apps = apps.list() }) end
end)

return apps
