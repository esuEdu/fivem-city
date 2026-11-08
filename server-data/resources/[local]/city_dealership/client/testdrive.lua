-- Test drive on the client: a countdown on screen, and the way back to the showroom when the server ends it.
local testDrive = {}

local endsAt

---@return boolean
function testDrive.active()
    return endsAt ~= nil
end

local function countdown()
    while endsAt do
        local left = math.max(0, endsAt - GetGameTimer())

        lib.showTextUI(locale('test_drive_left', math.ceil(left / 1000)), { position = 'top-center', icon = 'fas fa-stopwatch' })
        Wait(1000)
    end

    lib.hideTextUI()
end

---@param model string
function testDrive.start(model)
    if endsAt then return end

    local ok, result = lib.callback.await('city_dealership:testDrive', false, model)

    if not ok then
        return exports.qbx_core:Notify(locale(('error_%s'):format(result or 'failed')), 'error')
    end

    endsAt = GetGameTimer() + result * 1000
    exports.qbx_core:Notify(locale('test_drive_started', result), 'inform')
    CreateThread(countdown)
end

RegisterNetEvent('city_dealership:client:testDriveEnded', function()
    if not endsAt then return end

    endsAt = nil

    local back = Config.TestDrive.returnTo

    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end

    SetEntityCoords(cache.ped, back.x, back.y, back.z, false, false, false, false)
    SetEntityHeading(cache.ped, back.w)
    Wait(300)
    DoScreenFadeIn(400)

    exports.qbx_core:Notify(locale('test_drive_ended'), 'inform')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not endsAt then return end

    endsAt = nil
    lib.hideTextUI()
end)

return testDrive
