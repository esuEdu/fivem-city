-- Test command: sends a player (yourself by default) to prison the same way an MDT arrest does

local settings = require 'server.config'
local inmates = require 'server.inmates'

local DEFAULT_MONTHS = 5

lib.addCommand('testjail', {
    help = locale('command_testjail'),
    params = {
        { name = 'id', type = 'playerId', help = locale('param_id'), optional = true },
        { name = 'months', type = 'number', help = locale('param_months'), optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    -- source 0 = server console, which has to name a player
    local target = args.id or (source ~= 0 and source or nil)
    local months = math.tointeger(args.months) or DEFAULT_MONTHS

    local function reply(text)
        if source == 0 then return lib.print.info(text) end
        exports.qbx_core:Notify(source, text, 'inform')
    end

    if not target or not exports.qbx_core:GetPlayer(target) then return reply(locale('test_no_player')) end
    if months < 1 or months > settings.maxMonths then return reply(locale('test_bad_months', settings.maxMonths)) end

    if not inmates.jail(target, months, 'Staff test') then return reply(locale('test_failed')) end

    lib.print.info(('city_prison: %s sent %s to prison for %d months (testjail)'):format(source == 0 and 'console' or GetPlayerName(source), GetPlayerName(target), months))
    reply(locale('test_jailed', GetPlayerName(target), months))
end)
