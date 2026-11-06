-- Test tools for admins: /bankwarp moves one character's bank dates back, so overdue bills, late fees, retention,
-- the debt freeze, card invoice cycles, loan installments and scheduled transfers can be tested without waiting days.
-- Ledger entries are never touched (append-only), so the savings yield still uses the real last 24 hours.
local access = require 'server.access'

local DAY = 86400

lib.addCommand('bankwarp', {
    help = locale('command_bankwarp'),
    params = {
        { name = 'id', type = 'playerId', help = locale('param_id') },
        { name = 'days', type = 'number', help = locale('param_days') },
    },
    restricted = 'group.admin',
}, function(source, args)
    -- source 0 = server console
    if source ~= 0 and not exports.qbx_core:IsOptin(source) then
        return exports.qbx_core:Notify(source, locale('not_on_duty'), 'error')
    end

    local target = exports.qbx_core:GetPlayer(args.id)
    local days = math.tointeger(args.days)

    if not target or not days or days < 1 or days > 60 then
        if source ~= 0 then exports.qbx_core:Notify(source, locale('error_bad_amount'), 'error') end
        return
    end

    local citizenid = target.PlayerData.citizenid
    local shift = days * DAY

    MySQL.update.await(
        [[UPDATE `bank_bills` SET `due_at` = `due_at` - ?, `created_at` = `created_at` - ? WHERE `citizenid` = ? AND `status` IN ('pending', 'overdue')]],
        { shift, shift, citizenid }
    )
    MySQL.update.await(
        [[UPDATE `bank_loans` SET `next_due` = `next_due` - ? WHERE `citizenid` = ? AND `status` = 'active']],
        { shift, citizenid }
    )
    MySQL.update.await(
        'UPDATE `bank_profiles` SET `cycle_start` = `cycle_start` - ?, `week_start` = `week_start` - ? WHERE `citizenid` = ? AND `cycle_start` > 0',
        { shift, shift, citizenid }
    )
    MySQL.update.await(
        [[UPDATE `bank_scheduled` SET `next_run` = `next_run` - ? WHERE `citizenid` = ? AND `status` = 'active']],
        { shift, citizenid }
    )
    MySQL.update.await(
        'UPDATE `bank_cards` SET `pending_at` = `pending_at` - ? WHERE `holder` = ? AND `pending_at` > 0',
        { shift, citizenid }
    )

    -- The daily step (overdue penalties, debt freeze, savings) runs on the next tick
    MySQL.update.await([[UPDATE `bank_state` SET `value` = 0 WHERE `name` = 'daily']])

    local actor = source == 0 and 'console' or access.name(exports.qbx_core:GetPlayer(source))

    access.audit(actor, 'bank_warp', citizenid, { days = days })
    TriggerEvent('city_bank:server:runScheduler')

    if source ~= 0 then exports.qbx_core:Notify(source, locale('notify_warped', days, access.name(target)), 'success') end
end)
