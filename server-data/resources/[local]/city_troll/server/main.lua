local DEFAULT_FORCE = 60
local MAX_FORCE = 200

lib.addCommand('launch', {
    help = 'Launch a player into the sky',
    params = {
        { name = 'id', type = 'playerId', help = 'Player ID' },
        { name = 'force', type = 'number', help = ('Upward speed, default %d'):format(DEFAULT_FORCE), optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    -- Same admin-duty rule as the Qbox admin commands (source 0 = server console)
    if source ~= 0 and not exports.qbx_core:IsOptin(source) then
        exports.qbx_core:Notify(source, 'You are not opted in for admin duty. (/optin to toggle)', 'error')
        return
    end

    local force = math.min(math.max(args.force or DEFAULT_FORCE, 10), MAX_FORCE)
    TriggerClientEvent('city_troll:client:launch', args.id, force)

    if source ~= 0 then
        exports.qbx_core:Notify(source, ('Launched %s into the sky'):format(GetPlayerName(args.id)), 'success')
    end
end)
