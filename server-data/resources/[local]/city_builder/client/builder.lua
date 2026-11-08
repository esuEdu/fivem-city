-- The editor session: freecam, the overlay page, and what its buttons and keys do. The server checks every change.
local theme = require '@city_ui.theme'
local world = require 'client.world'
local freecam = require 'client.freecam'
local editor = require 'client.editor'
local history = require 'client.history'

local active = false
local looking = false
local lookingSince = 0
local customModels

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function sendTarget()
    send('target', editor.state())
end

local function sendHistory()
    send('history', history.counts())
end

local function groupList()
    local counts = {}
    for _, prop in pairs(world.props) do
        if prop.group then counts[prop.group] = (counts[prop.group] or 0) + 1 end
    end

    local list = {}
    for id, group in pairs(world.groups) do
        list[#list + 1] = { id = id, name = group.name, enabled = group.enabled, count = counts[id] or 0 }
    end

    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)

    return list
end

local function placedList()
    local origin = freecam.coords()
    local rows = {}

    for _, entry in ipairs(world.nearest(origin, Config.ListLimit)) do
        local prop, group = entry.prop, entry.prop.group and world.groups[entry.prop.group]
        rows[#rows + 1] = { id = prop.id, model = prop.model, distance = entry.distance, group = group and group.name }
    end

    return rows
end

local function hideList()
    local origin = freecam.coords()
    local rows = {}

    for id, hide in pairs(world.hides) do
        rows[#rows + 1] = { id = id, label = hide.label, distance = #(origin - vector3(hide.x, hide.y, hide.z)) }
    end

    table.sort(rows, function(a, b) return a.distance < b.distance end)

    return rows
end

---Keeps only the streamed names this client can spawn as props, a few hundred per frame.
local function checkCustom(names)
    local list = {}

    for i, name in ipairs(names) do
        local hash = joaat(name)
        if IsModelInCdimage(hash) and not IsModelAVehicle(hash) then list[#list + 1] = name end
        if i % 250 == 0 then Wait(0) end
    end

    return list
end

local function setLooking(value)
    looking = value
    lookingSince = GetGameTimer()
    SetNuiFocus(not value, not value)
    send('looking', value)
end

local function stop()
    if not active then return end

    active = false
    looking = false
    editor.clear()
    history.reset()
    freecam.stop()
    SetNuiFocus(false, false)
    send('close')

    FreezeEntityPosition(cache.ped, false)
    SetEntityInvincible(cache.ped, false)

    world.builder = false
    world.refresh()
end

local function start()
    if active then return end

    if cache.vehicle then
        return lib.notify({ description = locale('leave_vehicle'), type = 'error' })
    end

    local ok, info = history.op('start')
    if not ok then return end

    active = true
    world.builder = true
    world.refresh()

    FreezeEntityPosition(cache.ped, true)
    SetEntityInvincible(cache.ped, true)
    freecam.start()

    send('open', {
        theme = theme,
        labels = lib.getLocales(),
        count = info.count,
        max = info.max,
        groups = groupList(),
        hideRadius = Config.HideRadius,
        keys = { move = Config.MoveStep, moveFine = Config.MoveStepFine, rotate = Config.RotateStep, rotateFine = Config.RotateStepFine },
    })
    setLooking(false)
    sendHistory()

    CreateThread(function()
        customModels = customModels or checkCustom(info.models or {})
        if active then send('custom', customModels) end
    end)

    CreateThread(function()
        while active do
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)

            if looking then
                DisableAllControlActions(0)
                freecam.fly()

                local t = editor.target
                if t and t.follow then editor.followScreen(0.5, 0.5) sendTarget() end

                -- Holding the right button flies until it's let go; if the game missed the press (it began on the
                -- page), a second right click, Esc or Backspace stops flying instead
                if GetGameTimer() - lookingSince > 200 and (IsDisabledControlJustReleased(0, 25) or IsDisabledControlJustPressed(0, 25)
                    or IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 177)) then
                    setLooking(false)
                end
            end

            editor.draw()

            if IsEntityDead(cache.ped) then stop() end

            Wait(0)
        end
    end)
end

AddEventHandler('city_builder:client:start', start)

-- Another staff member changed something: refresh the lists that are open
AddEventHandler('city_builder:client:changed', function()
    if not active then return end

    local count = 0
    for _ in pairs(world.props) do count = count + 1 end

    send('count', count)
    send('groups', groupList())

    local t = editor.target
    if t and t.id and not world.props[t.id] then
        editor.target = nil
        sendTarget()
    end
end)

local function reply(cb, value)
    cb(value == nil and true or value)
end

RegisterNUICallback('look', function(_, cb)
    reply(cb)
    if active then setLooking(true) end
end)

RegisterNUICallback('cursor', function(data, cb)
    reply(cb)

    local t = editor.target
    if not active or not t or not t.follow or type(data) ~= 'table' then return end

    local x, y = tonumber(data.x), tonumber(data.y)
    if not x or not y then return end

    editor.followScreen(x, y)
    sendTarget()
end)

RegisterNUICallback('click', function(data, cb)
    reply(cb)
    if not active or type(data) ~= 'table' then return end

    local t = editor.target
    if t and t.follow then
        t.follow = false
        return sendTarget()
    end

    local x, y = tonumber(data.x), tonumber(data.y)
    if not x or not y then return end

    local hit, _, entity = freecam.raycast(x, y, t and t.entity)
    local id = hit and world.byEntity[entity]

    if id then
        editor.picked = nil
        editor.startEdit(id)
        send('picked', nil)
        return sendTarget()
    end

    if hit and entity ~= 0 and GetEntityType(entity) == 3 and not (t and entity == t.entity) then
        local coords = GetEntityCoords(entity)
        local hash = GetEntityModel(entity)

        editor.cancel()
        editor.picked = { entity = entity, hash = hash, coords = coords }
        send('picked', { hash = hash, x = coords.x, y = coords.y, z = coords.z })
        return sendTarget()
    end

    editor.cancel()
    editor.picked = nil
    send('picked', nil)
    sendTarget()
end)

RegisterNUICallback('preview', function(data, cb)
    local model = type(data) == 'table' and data.model
    if not active or not editor.validModel(model) then return cb({ ok = false }) end

    if not editor.showPreview(model) then return cb({ ok = false }) end

    cb({ ok = true, size = editor.preview.size })
end)

RegisterNUICallback('previewEnd', function(_, cb)
    reply(cb)
    editor.hidePreview()
end)

RegisterNUICallback('pick', function(data, cb)
    local model = type(data) == 'table' and data.model
    if not active or not editor.validModel(model) then return cb({ ok = false }) end

    editor.hidePreview()
    editor.picked = nil
    send('picked', nil)

    local ok = editor.startNew(model)
    sendTarget()
    cb({ ok = ok })
end)

RegisterNUICallback('nudge', function(data, cb)
    reply(cb)
    if not active or type(data) ~= 'table' then return end

    editor.nudge(data.kind, tonumber(data.dir), data.fine == true)
    sendTarget()
end)

RegisterNUICallback('set', function(data, cb)
    reply(cb)
    if not active then return end

    editor.set(data)
    sendTarget()
end)

RegisterNUICallback('follow', function(_, cb)
    reply(cb)

    local t = editor.target
    if active and t then t.follow = true end
    sendTarget()
end)

RegisterNUICallback('ground', function(_, cb)
    reply(cb)
    if not active then return end

    editor.ground()
    sendTarget()
end)

RegisterNUICallback('save', function(data, cb)
    local payload = active and editor.payload()
    if not payload then return cb({ ok = false }) end

    local t = editor.target
    local ok, result = history.op(payload.id and 'update' or 'create', payload)
    if not ok then return cb({ ok = false }) end

    if payload.id then
        history.push({ kind = 'update', id = payload.id, before = t.original, after = result })
    else
        history.push({ kind = 'create', id = result.id, data = result })
    end

    editor.release()

    -- Keep stamping copies of a new prop until the builder picks something else
    if not payload.id and type(data) == 'table' and data.again then
        if editor.startNew(payload.model, payload) then editor.target.follow = true end
    end

    sendTarget()
    sendHistory()
    cb({ ok = true })
end)

RegisterNUICallback('cancel', function(_, cb)
    reply(cb)
    editor.cancel()
    sendTarget()
end)

RegisterNUICallback('duplicate', function(_, cb)
    reply(cb)

    local payload = active and editor.payload()
    if not payload or not payload.id then return end

    editor.cancel()
    local _, yaw = freecam.rotation()
    payload.x = payload.x + math.cos(math.rad(yaw))
    payload.y = payload.y + math.sin(math.rad(yaw))
    editor.startNew(payload.model, payload)
    sendTarget()
end)

RegisterNUICallback('delete', function(_, cb)
    local t = active and editor.target
    if not t or not t.id then return cb({ ok = false }) end

    local ok, result = history.op('delete', t.id)
    if ok then
        editor.target = nil
        history.push({ kind = 'delete', id = t.id, data = result })
    end

    sendTarget()
    sendHistory()
    cb({ ok = ok })
end)

RegisterNUICallback('hide', function(data, cb)
    local picked = active and editor.picked
    if not picked then return cb({ ok = false }) end

    local label = type(data) == 'table' and type(data.label) == 'string' and data.label or nil
    local ok, result = history.op('hide', { model = picked.hash, label = label, x = picked.coords.x, y = picked.coords.y, z = picked.coords.z })

    if ok then
        editor.picked = nil
        history.push({ kind = 'hide', id = result.id, data = result })
        send('picked', nil)
    end

    sendHistory()
    cb({ ok = ok })
end)

RegisterNUICallback('unhide', function(data, cb)
    local id = active and type(data) == 'table' and math.tointeger(data.id)
    if not id then return cb({ ok = false }) end

    local ok, result = history.op('unhide', id)
    if ok then history.push({ kind = 'unhide', id = id, data = result }) end

    sendHistory()
    cb({ ok = ok, list = hideList() })
end)

RegisterNUICallback('history', function(data, cb)
    if not active then return cb({ ok = false }) end

    editor.cancel()
    local ok = history.step(type(data) == 'table' and data.undo == true)

    sendTarget()
    sendHistory()
    cb({ ok = ok })
end)

RegisterNUICallback('lists', function(_, cb)
    if not active then return cb({}) end

    cb({ placed = placedList(), hides = hideList(), groups = groupList() })
end)

RegisterNUICallback('goto', function(data, cb)
    reply(cb)
    if not active or type(data) ~= 'table' then return end

    local id = math.tointeger(data.id)
    local item = id and (data.hide and world.hides[id] or world.props[id])
    if not item then return end

    editor.cancel()
    freecam.lookAt(vector3(item.x, item.y, item.z), 6.0)
    sendTarget()

    if data.hide then return end

    -- The prop spawns on the world loop's next pass
    CreateThread(function()
        for _ = 1, 20 do
            if not active then return end
            if world.spawned[id] then
                editor.startEdit(id)
                return sendTarget()
            end
            Wait(100)
        end
    end)
end)

RegisterNUICallback('group', function(data, cb)
    if not active or type(data) ~= 'table' then return cb({ ok = false }) end

    local action = data.action
    local ok

    if action == 'create' then
        ok = history.op('groupCreate', data.name)
    elseif action == 'update' then
        ok = history.op('groupUpdate', { id = data.id, name = data.name, enabled = data.enabled })
    elseif action == 'delete' then
        ok = history.op('groupDelete', data.id)
    elseif action == 'move' then
        ok = history.op('groupMove', { id = data.id, x = tonumber(data.x), y = tonumber(data.y), z = tonumber(data.z) })
    elseif action == 'goto' then
        local id, sum, count = math.tointeger(data.id), vector3(0.0, 0.0, 0.0), 0
        for _, prop in pairs(world.props) do
            if prop.group == id then sum, count = sum + vector3(prop.x, prop.y, prop.z), count + 1 end
        end
        if count > 0 then freecam.lookAt(sum / count, 15.0) end
        ok = count > 0
    end

    cb({ ok = ok == true, groups = groupList() })
end)

RegisterNUICallback('exit', function(_, cb)
    reply(cb)
    stop()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then stop() end
end)
