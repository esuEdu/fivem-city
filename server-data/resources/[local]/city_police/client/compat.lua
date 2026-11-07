-- qbx_police's client event that other scripts still fire: the panic button (qbx_radialmenu, also while down).
-- See docs/city-police.md.

local job = require 'client.job'

AddEventHandler('police:client:SendPoliceEmergencyAlert', function()
    if not job.onDuty() then return end

    TriggerServerEvent('city_police:server:panic')
    -- EMS get an "officer down" call in city_hospital too
    TriggerServerEvent('hospital:server:ambulanceAlert')
    exports.qbx_core:Notify(locale('panic_sent'), 'error')
end)
