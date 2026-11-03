local Items = require 'shared.items'

---Notifies the admin, or prints when the command came from the server console (source 0).
---@param source integer
---@param message string
---@param notifyType 'success' | 'error'
local function reply(source, message, notifyType)
    if source == 0 then
        lib.print.info(message)
    else
        exports.qbx_core:Notify(source, message, notifyType)
    end
end

lib.addCommand('giveitem', {
    help = locale('command_giveitem'),
    params = {
        { name = 'id', type = 'playerId', help = locale('param_id') },
        { name = 'item', type = 'string', help = locale('param_item') },
        { name = 'count', type = 'number', help = locale('param_count'), optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    -- Same admin-duty rule as the Qbox admin commands
    if source ~= 0 and not exports.qbx_core:IsOptin(source) then
        return reply(source, locale('not_on_duty'), 'error')
    end

    local name = args.item:lower()
    if not Items[name] then
        return reply(source, locale('unknown_item', name), 'error')
    end

    local count = args.count or 1
    local success, reason = exports[cache.resource]:AddItem(args.id, name, count)

    if success then
        reply(source, locale('gave_item', count, Items[name].label, GetPlayerName(args.id)), 'success')
    else
        reply(source, locale('give_failed', Items[name].label, reason), 'error')
    end
end)
