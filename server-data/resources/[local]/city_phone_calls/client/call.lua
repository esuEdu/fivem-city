-- What happens on this player's side of a call: the phone opening for an incoming call (or a notification in Do Not
-- Disturb), the call in the dynamic island, mute, and closing the phone again if the call opened it.
local texts = require 'shared.texts'

local APP = 'phone'

local current
local openedByCall = false
local muted = {}

local function t(key)
    local settings = exports.city_phone:GetSettings() or {}
    local list = texts[settings.language] or texts.en
    return list[key] or texts.en[key] or key
end

local function format(number)
    if not number or number == '' then return t('unknown') end
    if #number == 10 then return ('(%s) %s-%s'):format(number:sub(1, 3), number:sub(4, 6), number:sub(7)) end
    return number
end

local function who(call)
    local first = call.people[1]
    if not first then return t('unknown') end

    local extra = #call.people > 1 and (' +%d'):format(#call.people - 1) or ''
    return format(first.number) .. extra
end

local function setMute(src, value)
    if (exports['pma-voice']:isPlayerMuted(src) == true) == value then return end

    exports['pma-voice']:toggleMutePlayer(src)
    muted[src] = value or nil

    -- Unmuted: back to the call volume (pma-voice's unmute resets it)
    if not value then MumbleSetVolumeOverrideByServerId(src, exports['pma-voice']:getCallVolume() / 100) end
end

local function unmuteAll()
    for src in pairs(muted) do setMute(src, false) end
    muted = {}
end

-- The island: "Calling...", or the other person and the time talking
local function island()
    CreateThread(function()
        while current do
            local text, detail = who(current), t(current.status)

            if current.status == 'active' and current.since then
                local seconds = GetCloudTimeAsInt() - current.since
                detail = ('%d:%02d'):format(math.floor(seconds / 60), seconds % 60)
            end

            exports.city_phone:SetActivity('call', { icon = 'phone', color = '#34c759', text = text, detail = detail })
            Wait(1000)
        end

        exports.city_phone:SetActivity('call', nil)
    end)
end

local function incoming(call)
    local settings = exports.city_phone:GetSettings() or {}

    if settings.dnd then
        exports.city_phone:Notify({ app = 'phone', title = t('incoming'), text = who(call), force = true, sound = false })
        return
    end

    exports.city_phone:OpenApp(APP)

    if not exports.city_phone:IsOpen() then
        openedByCall = exports.city_phone:Open()
    end
end

RegisterNetEvent('city_phone_calls:client:call', function(call)
    if GetInvokingResource() then return end

    local previous = current
    current = call or nil

    exports.city_phone:SendAppMessage(APP, { action = 'call', call = current })

    if current and not previous then
        if current.incoming then incoming(current) end
        island()
    end

    if not current then
        unmuteAll()

        if openedByCall then
            openedByCall = false
            exports.city_phone:Close()
        end
    end
end)

RegisterNetEvent('city_phone_calls:client:missed', function(number)
    if GetInvokingResource() then return end

    exports.city_phone:Notify({ app = 'phone', title = t('missed'), text = format(number) })
    exports.city_phone:SendAppMessage(APP, { action = 'refresh' })
end)

RegisterNetEvent('city_phone_calls:client:muted', function(src, value)
    if GetInvokingResource() or type(src) ~= 'number' then return end
    setMute(src, value == true)
end)

-- Someone shared their contact: a notification with "Save"
RegisterNetEvent('city_phone_calls:client:offer', function(id, name, number)
    if GetInvokingResource() then return end

    exports.city_phone:Notify({
        app = 'phone',
        title = t('shared'),
        text = ('%s · %s'):format(name, format(number)),
        action = { event = 'city_phone_calls:client:acceptOffer', data = id },
    })
end)

AddEventHandler('city_phone_calls:client:acceptOffer', function(id)
    local ok, name = lib.callback.await('city_phone_calls:acceptOffer', false, id)

    exports.city_phone:Notify({ app = 'phone', title = t(ok and 'saved' or 'not_saved'), text = ok and name or nil, sound = false })
    if ok then exports.city_phone:SendAppMessage(APP, { action = 'refresh' }) end
end)

-- The app's page asks to mute; tell the server (which tells the others)
RegisterNUICallback('mute', function(data, cb)
    cb({ ok = lib.callback.await('city_phone_calls:mute', false, data.muted == true) == true })
end)

-- Losing the phone item ends the call
AddEventHandler('ox_inventory:itemCount', function(name, count)
    if name == Config.Item and count < 1 and current then lib.callback.await('city_phone_calls:hangup', false) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    unmuteAll()
    if current then exports.city_phone:SetActivity('call', nil) end
end)
