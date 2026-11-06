-- What happens on a player's own client when staff act on them.

RegisterNetEvent('city_staff:client:kill', function()
    -- Only from the server, not another resource on this client
    if GetInvokingResource() then return end

    SetEntityHealth(cache.ped, 0)
end)

RegisterNetEvent('city_staff:client:warned', function(reason)
    if GetInvokingResource() or type(reason) ~= 'string' then return end

    lib.alertDialog({
        header = locale('warned_title'),
        content = locale('warned_text', reason),
        centered = true,
        cancel = false,
    })
end)
