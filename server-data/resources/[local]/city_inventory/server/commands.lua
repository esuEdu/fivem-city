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

---Same admin-duty rule as the Qbox admin commands; source 0 is the server console.
---@param source integer
---@return boolean
local function isOnDuty(source)
    if source == 0 or exports.qbx_core:IsOptin(source) then return true end

    reply(source, locale('not_on_duty'), 'error')
    return false
end

local kits = {}
local kitNames = {}

for _, kit in ipairs(Config.Kits) do
    kits[kit.name] = kit.items
    kitNames[#kitNames + 1] = kit.name
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
    if not isOnDuty(source) then return end

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

lib.addCommand('kit', {
    help = locale('command_kit'),
    params = {
        { name = 'kit', type = 'string', help = locale('param_kit', table.concat(kitNames, ', ')), optional = true },
        { name = 'id', type = 'playerId', help = locale('param_kit_id'), optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    if not isOnDuty(source) then return end

    local name = args.kit and args.kit:lower() or kitNames[1]
    local items = kits[name]
    if not items then
        return reply(source, locale('unknown_kit', name), 'error')
    end

    local target = args.id or source
    if target == 0 then
        return reply(source, locale('param_kit_id'), 'error')
    end

    for _, entry in ipairs(items) do
        local item, count = entry[1], entry[2]
        local success, reason = exports[cache.resource]:AddItem(target, item, count)

        if not success then
            reply(source, locale('give_failed', Items[item] and Items[item].label or item, reason), 'error')
        end
    end

    reply(source, locale('gave_kit', name, GetPlayerName(target)), 'success')
end)
