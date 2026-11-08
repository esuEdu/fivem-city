-- Life inside, only while serving: the job board and the current job spot, water fountains, the food tray and the
-- contraband spots. All ox_target zones, made when the inmate goes in and removed when they leave.

local zones = {}
local jobZone, jobBlip
local job, spot
local busy = false

local function addZone(coords, options)
    zones[#zones + 1] = exports.ox_target:addSphereZone({ coords = coords, radius = 1.2, options = options })
end

local function fail(reason)
    if reason then lib.notify({ description = locale('error_' .. reason), type = 'error' }) end
end

local function playAnim(anim)
    if anim.scenario then
        TaskStartScenarioInPlace(cache.ped, anim.scenario, 0, true)
    else
        lib.requestAnimDict(anim.dict)
        TaskPlayAnim(cache.ped, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
        RemoveAnimDict(anim.dict)
    end
end

---A progress bar that the server started and will check
local function progress(seconds, label, anim)
    if anim then playAnim(anim) end

    local done = lib.progressBar({
        duration = math.floor(seconds * 1000),
        label = label,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    ClearPedTasks(cache.ped)
    return done
end

local function clearJobSpot()
    if jobZone then exports.ox_target:removeZone(jobZone) end
    if jobBlip then RemoveBlip(jobBlip) end
    jobZone, jobBlip = nil, nil
end

local doTask

local function showJobSpot()
    clearJobSpot()
    if not job or not spot then return end

    local coords = Config.Jobs[job].spots[spot]

    jobBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(jobBlip, 1)
    SetBlipColour(jobBlip, 5)
    SetBlipScale(jobBlip, 0.6)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('job_' .. job))
    EndTextCommandSetBlipName(jobBlip)

    jobZone = exports.ox_target:addSphereZone({
        coords = coords,
        radius = 1.2,
        options = { { name = 'city_prison:task', icon = Config.Jobs[job].icon, label = locale('task_' .. job), onSelect = function() doTask() end } },
    })
end

function doTask()
    if busy or not job then return end
    busy = true

    local ok, seconds = lib.callback.await('city_prison:beginTask', false)
    if not ok then
        busy = false
        return fail(seconds)
    end

    local settings = Config.Jobs[job]
    local done = progress(seconds, locale('task_' .. job), settings.anim)

    if done and settings.skillCheck then done = lib.skillCheck(settings.skillCheck) end

    if not done then
        busy = false
        return lib.notify({ description = locale('task_failed'), type = 'error' })
    end

    local finished, result = lib.callback.await('city_prison:finishTask', false)
    busy = false
    if not finished then return fail(result) end

    spot = result.spot
    showJobSpot()

    if result.taken > 0 then
        lib.notify({ description = locale('task_done', result.taken), type = 'success' })
    else
        lib.notify({ description = locale('task_done_cap'), type = 'inform' })
    end
end

local function takeJob(name)
    local ok, result = lib.callback.await('city_prison:takeJob', false, name)
    if not ok then return fail(result) end

    job, spot = name, result
    showJobSpot()
    lib.notify({ description = locale('job_taken', locale('job_' .. name)), type = 'inform' })
end

local function quitJob()
    lib.callback.await('city_prison:quitJob', false)
    job, spot = nil, nil
    clearJobSpot()
end

local function search(index)
    if busy then return end
    busy = true

    local ok, seconds = lib.callback.await('city_prison:beginSearch', false, index)
    if not ok then
        busy = false
        return fail(seconds)
    end

    local done = progress(seconds, locale('searching'), { dict = 'amb@prop_human_bum_bin@base', clip = 'base' })
    if not done then
        busy = false
        return
    end

    local finished, label = lib.callback.await('city_prison:finishSearch', false, index)
    busy = false

    if not finished then return fail(label) end
    lib.notify({ description = label and locale('found', label) or locale('found_nothing'), type = label and 'success' or 'inform' })
end

local function simple(name, index, okText)
    local ok, reason = lib.callback.await(name, false, index)
    if not ok then return fail(reason) end

    lib.notify({ description = okText, type = 'success' })
end

local function create()
    local options = {}

    for name, settings in pairs(Config.Jobs) do
        options[#options + 1] = {
            name = 'city_prison:job_' .. name,
            icon = settings.icon,
            label = locale('take_job', locale('job_' .. name)),
            onSelect = function() takeJob(name) end,
        }
    end

    options[#options + 1] = {
        name = 'city_prison:quit_job',
        icon = 'fas fa-xmark',
        label = locale('quit_job'),
        canInteract = function() return job ~= nil end,
        onSelect = quitJob,
    }

    addZone(Config.JobBoard, options)

    for index, coords in ipairs(Config.Fountains) do
        addZone(coords, { {
            name = 'city_prison:drink', icon = 'fas fa-glass-water', label = locale('target_drink'),
            onSelect = function() simple('city_prison:drink', index, locale('drank')) end,
        } })
    end

    addZone(Config.Tray, { {
        name = 'city_prison:eat', icon = 'fas fa-bowl-food', label = locale('target_tray'),
        onSelect = function() simple('city_prison:eat', nil, locale('ate')) end,
    } })

    for index, coords in ipairs(Config.Contraband) do
        addZone(coords, { {
            name = 'city_prison:search', icon = 'fas fa-magnifying-glass', label = locale('target_search'),
            onSelect = function() search(index) end,
        } })
    end
end

local function remove()
    for _, id in ipairs(zones) do exports.ox_target:removeZone(id) end
    zones = {}
    job, spot = nil, nil
    clearJobSpot()
end

AddEventHandler('city_prison:client:inside', function(inside)
    remove()
    if inside then create() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then remove() end
end)
