-- Things done to another player: check a pulse (anyone), carry a body (anyone), and the EMS actions (examine, revive,
-- treat, bill). Also the qbx_radialmenu events that used to go to qbx_ambulancejob.
local REACH = 3.0

local function serverIdOf(entity)
    return GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
end

local function isDown(entity)
    return Player(serverIdOf(entity)).state.isDead == true
end

local function emsOnDuty()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job ~= nil and job.type == Config.JobType and job.onduty == true
end

local function leoOnDuty()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job ~= nil and job.type == 'leo' and job.onduty == true
end

local function closest()
    local playerId = lib.getClosestPlayer(GetEntityCoords(cache.ped), REACH, false)
    if not playerId then exports.qbx_core:Notify(locale('notify_no_patient'), 'error') end

    return playerId and GetPlayerServerId(playerId)
end

local REASONS = {
    not_down = 'notify_not_down',
    finalized = 'notify_finalized_target',
}

local function checkPulse(target)
    local result = lib.callback.await('city_hospital:pulse', false, target)
    if not result then return end

    exports.qbx_core:Notify(locale(('pulse_%s'):format(result)), result == 'gone' and 'error' or 'inform')
end

local function examine(target)
    local status = lib.callback.await('city_hospital:examine', false, target)
    if not status then return end

    local lines = {}

    for part, injury in pairs(status.injuries or {}) do
        local severity = type(injury) == 'table' and injury.severity or injury
        lines[#lines + 1] = ('- %s: %s'):format(locale(('body_%s'):format(part)), locale('menu_severity', severity))
    end

    if (status.isBleeding or 0) > 0 then lines[#lines + 1] = locale('menu_bleeding', status.isBleeding) end
    if #lines == 0 then lines[1] = locale('menu_no_injuries') end

    lib.alertDialog({ header = locale('menu_examine'), content = table.concat(lines, '  \n'), centered = true })
end

---@param kind 'revive' | 'treat'
local function work(kind, target)
    local item = kind == 'revive' and 'firstaid' or 'bandage'
    local ok, reason = lib.callback.await('city_hospital:startAction', false, kind, target)

    if not ok then
        if reason == 'no_item' then return exports.qbx_core:Notify(locale('notify_no_item', item), 'error') end
        return exports.qbx_core:Notify(locale(REASONS[reason] or 'notify_no_patient'), 'error')
    end

    local anim = Config.Anims.cpr
    local done = lib.progressBar({
        duration = (kind == 'revive' and 8000 or 5000),
        label = locale(kind == 'revive' and 'progress_revive' or 'progress_treat'),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = anim.dict, clip = anim.clip, flag = 1 },
    })

    StopAnimTask(cache.ped, anim.dict, anim.clip, 1.0)

    -- Cancelled: still tell the server, so the started action is dropped
    local finished, why = lib.callback.await('city_hospital:finishAction', false)
    if not done then return end

    if finished then
        exports.qbx_core:Notify(locale('notify_done'), 'success')
    elseif why then
        exports.qbx_core:Notify(locale(why == 'no_item' and 'notify_no_item' or (REASONS[why] or 'notify_no_patient'), item), 'error')
    end
end

local function bill(target)
    local input = lib.inputDialog(locale('input_bill'), {
        { type = 'number', label = locale('input_amount'), required = true, min = 1 },
        { type = 'input', label = locale('input_note'), max = 60 },
    })
    if not input then return end

    local ok = lib.callback.await('city_hospital:bill', false, target, math.floor(tonumber(input[1]) or 0), input[2])
    exports.qbx_core:Notify(locale(ok and 'notify_bill_sent' or 'notify_bill_failed'), ok and 'success' or 'error')
end

local OPTIONS = {
    {
        name = 'city_hospital:pulse', label = locale('target_pulse'), icon = 'fas fa-heart-pulse', distance = REACH,
        canInteract = function(entity) return isDown(entity) and not LocalPlayer.state.isDead end,
        onSelect = function(data) checkPulse(serverIdOf(data.entity)) end,
    },
    {
        name = 'city_hospital:carry', label = locale('target_carry'), icon = 'fas fa-people-carry-box', distance = REACH,
        canInteract = function(entity) return isDown(entity) and not LocalPlayer.state.isDead and not cache.vehicle end,
        onSelect = function(data) TriggerEvent('city_hospital:client:carry', serverIdOf(data.entity)) end,
    },
    {
        name = 'city_hospital:examine', label = locale('target_examine'), icon = 'fas fa-stethoscope', distance = REACH,
        canInteract = emsOnDuty,
        onSelect = function(data) examine(serverIdOf(data.entity)) end,
    },
    {
        name = 'city_hospital:revive', label = locale('target_revive'), icon = 'fas fa-kit-medical', distance = REACH,
        canInteract = function(entity) return emsOnDuty() and isDown(entity) end,
        onSelect = function(data) work('revive', serverIdOf(data.entity)) end,
    },
    {
        name = 'city_hospital:treat', label = locale('target_treat'), icon = 'fas fa-bandage', distance = REACH,
        canInteract = emsOnDuty,
        onSelect = function(data) work('treat', serverIdOf(data.entity)) end,
    },
    {
        name = 'city_hospital:bill', label = locale('target_bill'), icon = 'fas fa-file-invoice-dollar', distance = REACH,
        canInteract = emsOnDuty,
        onSelect = function(data) bill(serverIdOf(data.entity)) end,
    },
}

local optionNames = {}
for i, option in ipairs(OPTIONS) do optionNames[i] = option.name end

exports.ox_target:addGlobalPlayer(OPTIONS)

-- qbx_radialmenu's EMS buttons fire these (they were qbx_ambulancejob's)
AddEventHandler('hospital:client:CheckStatus', function()
    local target = (emsOnDuty() or leoOnDuty()) and closest()
    if target then examine(target) end
end)

AddEventHandler('hospital:client:RevivePlayer', function()
    local target = emsOnDuty() and closest()
    if target then work('revive', target) end
end)

AddEventHandler('hospital:client:TreatWounds', function()
    local target = emsOnDuty() and closest()
    if target then work('treat', target) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    exports.ox_target:removeGlobalPlayer(optionNames)
end)
