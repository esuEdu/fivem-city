-- The panic button: /p (Config.PanicCommand, also "p" in F8 and bindable in the game's key bindings) and qbx_police's
-- client event that other scripts still fire (qbx_radialmenu, also while down). See docs/city-police.md.

local job = require 'client.job'

local function panic()
    if not job.onDuty() then return job.fail('off_duty') end

    TriggerServerEvent('city_police:server:panic')
    -- EMS get an "officer down" call in city_hospital too
    TriggerServerEvent('hospital:server:ambulanceAlert')
    exports.qbx_core:Notify(locale('panic_sent'), 'error')
end

AddEventHandler('police:client:SendPoliceEmergencyAlert', panic)

RegisterCommand(Config.PanicCommand, panic, false)
TriggerEvent('chat:addSuggestion', ('/%s'):format(Config.PanicCommand), locale('panic_help'))

-- Unbound by default: officers pick their own key in Settings > Key Bindings > FiveM
RegisterKeyMapping(Config.PanicCommand, locale('key_panic'), 'keyboard', '')

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then TriggerEvent('chat:removeSuggestion', ('/%s'):format(Config.PanicCommand)) end
end)
