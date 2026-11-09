-- Sends the editor's changes to the server and keeps undo/redo for this editor session. Undoing a delete creates the
-- prop again with a new id, so later steps that name the old id are pointed at the new one.
local history = { undo = {}, redo = {} }

local LIMIT = 50
local remap = { prop = {}, hide = {} }

local function resolve(kind, id)
    local seen = 0

    while remap[kind][id] and seen < LIMIT * 2 do
        id, seen = remap[kind][id], seen + 1
    end

    return id
end

---@return boolean ok
---@return any result the server's answer, or the reason it refused
function history.op(action, args)
    local ok, result = lib.callback.await('city_builder:op', false, action, args)

    if not ok then
        lib.notify({ description = locale(('error_%s'):format(result or 'failed')), type = 'error' })
    end

    return ok, result
end

local function propArgs(prop, id)
    return {
        id = id, model = prop.model, x = prop.x, y = prop.y, z = prop.z, rx = prop.rx, ry = prop.ry, rz = prop.rz,
        collision = prop.collision, group = prop.group,
    }
end

local function hideArgs(hide)
    return { model = hide.model, label = hide.label, x = hide.x, y = hide.y, z = hide.z }
end

---Records a change that already happened on the server.
---@param entry { kind: 'create'|'delete'|'update'|'hide'|'unhide', id: integer, data?: table, before?: table, after?: table }
function history.push(entry)
    history.undo[#history.undo + 1] = entry
    if #history.undo > LIMIT then table.remove(history.undo, 1) end

    history.redo = {}
end

local function exists(kind, entry)
    local action = kind == 'prop' and 'create' or 'hide'
    local ok, result = history.op(action, kind == 'prop' and propArgs(entry.data) or hideArgs(entry.data))
    if ok then remap[kind][resolve(kind, entry.id)] = result.id end

    return ok
end

local function gone(kind, entry)
    return (history.op(kind == 'prop' and 'delete' or 'unhide', resolve(kind, entry.id)))
end

---Runs an entry backwards (undo) or forwards again (redo).
local function run(entry, backwards)
    local kind = entry.kind

    if kind == 'create' then
        return backwards and gone('prop', entry) or exists('prop', entry)
    elseif kind == 'delete' then
        return backwards and exists('prop', entry) or gone('prop', entry)
    elseif kind == 'hide' then
        return backwards and gone('hide', entry) or exists('hide', entry)
    elseif kind == 'unhide' then
        return backwards and exists('hide', entry) or gone('hide', entry)
    elseif kind == 'update' then
        return (history.op('update', propArgs(backwards and entry.before or entry.after, resolve('prop', entry.id))))
    end

    return false
end

function history.step(backwards)
    local from = backwards and history.undo or history.redo
    local to = backwards and history.redo or history.undo
    local entry = from[#from]
    if not entry then return false end

    from[#from] = nil
    if not run(entry, backwards) then return false end

    to[#to + 1] = entry

    return true
end

function history.counts()
    return { undo = #history.undo, redo = #history.redo }
end

function history.reset()
    history.undo, history.redo = {}, {}
    remap = { prop = {}, hide = {} }
end

return history
