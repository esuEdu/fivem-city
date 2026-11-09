-- Helpers the client scripts share (loaded with require)
local util = {}

local busy = false

---Runs a timed action: the server starts its clock, the progress bar plays here, then the server finishes it.
---Returns the finish callback's results, or nil when it was refused or canceled.
---@param start string callback that starts the action
---@param finish string callback that completes it
---@param args any[]
---@param progress { seconds: number, label: string, scenario?: string, anim?: table }
---@return boolean?, any
function util.timed(start, finish, args, progress)
    if busy then return end
    busy = true

    local ok, err = lib.callback.await(start, false, table.unpack(args))

    if not ok then
        busy = false
        exports.qbx_core:Notify(locale(('error_%s'):format(err or 'failed')), 'error')
        return
    end

    local done = lib.progressCircle({
        duration = progress.seconds * 1000,
        label = progress.label,
        position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = progress.scenario and { scenario = progress.scenario } or progress.anim,
    })

    if not done then
        busy = false
        exports.qbx_core:Notify(locale('canceled'), 'error')
        return
    end

    local result, extra = lib.callback.await(finish, false, table.unpack(args))
    busy = false

    if not result then
        exports.qbx_core:Notify(locale(('error_%s'):format(extra or 'failed')), 'error')
        return
    end

    return result, extra
end

---@return boolean
function util.busy()
    return busy
end

---@param value boolean
function util.setBusy(value)
    busy = value
end

---@param name string
---@return string
function util.label(name)
    local item = exports.city_inventory:Items(name)

    return item and item.label or name
end

return util
