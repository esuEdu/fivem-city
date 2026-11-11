-- The station doors (cells, armory, offices) are ox_doorlock doors only the police job opens and locks. They are
-- created once by name when missing, so doors staff changed with /doorlock keep their changes.

local settings = require 'server.config'

CreateThread(function()
    while GetResourceState('ox_doorlock') ~= 'started' do Wait(500) end
    -- ox_doorlock reads its doors from the database on start
    Wait(5000)

    local groups = { [Config.Job] = 0 }
    local created = 0

    for _, door in ipairs(settings.doors) do
        if not exports.ox_doorlock:getDoorFromName(door.name) then
            local data = lib.table.deepclone(door)
            data.groups = groups
            data.state = data.state or 1
            data.maxDistance = data.maxDistance or 2.0
            exports.ox_doorlock:createDoor(data)
            created = created + 1
        end
    end

    if created > 0 then lib.print.info(('created %d station doors in ox_doorlock'):format(created)) end
end)
