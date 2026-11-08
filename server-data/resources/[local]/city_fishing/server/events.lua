-- The clock for frenzies and tournaments: one check a minute.
local settings = require 'server.config'
local frenzy = require 'server.frenzy'
local tournaments = require 'server.tournaments'

local started = {}

CreateThread(function()
    local minutes = 0

    while true do
        Wait(60000)
        minutes = minutes + 1

        frenzy.tick()
        if minutes % settings.frenzy.checkMinutes == 0 then frenzy.roll() end

        tournaments.tick(started)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    GlobalState.fishingFrenzy = nil
    GlobalState.fishingTournament = nil
end)
