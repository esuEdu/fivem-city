-- Where the other officers on duty are, for the blips on every officer's map (client/unitblips.lua). Sent only to
-- officers on duty, every Config.UnitBlips.seconds (a lone officer gets just themself, which clears old blips).

local police = require 'server.police'
local roster = require 'server.roster'

CreateThread(function()
    while true do
        Wait(Config.UnitBlips.seconds * 1000)

        local officers = police.onDutyList()

        if #officers > 0 then
            local list = {}

            for _, src in ipairs(officers) do
                local ped = GetPlayerPed(src)

                if ped ~= 0 then
                    local coords = GetEntityCoords(ped)
                    local unit = roster.unit(src)

                    list[#list + 1] = {
                        id = src,
                        x = math.floor(coords.x * 10) / 10,
                        y = math.floor(coords.y * 10) / 10,
                        h = math.floor(GetEntityHeading(ped)),
                        car = GetVehiclePedIsIn(ped, false) ~= 0,
                        label = unit and unit.callsign and ('%s · %s'):format(unit.callsign, unit.name) or police.name(src),
                    }
                end
            end

            for _, src in ipairs(officers) do
                TriggerClientEvent('city_police:client:unitBlips', src, list)
            end
        end
    end
end)
