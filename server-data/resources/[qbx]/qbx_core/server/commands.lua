local config = require 'config.server'
local logger = require 'modules.logger'

GlobalState.PVPEnabled = config.server.pvp

---@param source Source
---@return boolean
local function checkOptin(source)
    if IsOptin(source) then return true end
    Notify(source, locale('error.not_optin'), 'error')
    return false
end

---@param source Source
---@param player Player?
---@return boolean
local function requirePlayer(source, player)
    if player then return true end
    Notify(source, locale('error.not_online'), 'error')
    return false
end

---@param target Source
---@param prefix string
---@param source Source
---@param message string
local function addOocMessage(target, prefix, source, message)
    exports.chat:addMessage(target --[[@as Source]], {
        color = { 0, 0, 255 },
        multiline = true,
        args = { ('%s | %s'):format(prefix, GetPlayerName(source)), message }
    })
end

lib.addCommand('job', {
    help = locale('command.job.help')
}, function(source)
    local PlayerJob = GetPlayer(source).PlayerData.job
    Notify(source, locale('info.job_info', PlayerJob?.label, PlayerJob?.grade.name, PlayerJob?.onduty))
end)

lib.addCommand('gang', {
    help = locale('command.gang.help')
}, function(source)
    local PlayerGang = GetPlayer(source).PlayerData.gang
    Notify(source, locale('info.gang_info', PlayerGang?.label, PlayerGang?.grade.name))
end)

lib.addCommand('ooc', {
    help = locale('command.ooc.help')
}, function(source, args)
    local message = table.concat(args, ' ')
    local players = GetPlayers()
    local player = GetPlayer(source)
    if not player then return end

    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    for _, v in pairs(players) do
        if v == source then
            addOocMessage(v, 'OOC', source, message)
        elseif #(playerCoords - GetEntityCoords(GetPlayerPed(v))) < 20.0 then
            addOocMessage(v, 'OOC', source, message)
        elseif IsPlayerAceAllowed(v --[[@as string]], 'admin') then
            if IsOptin(v --[[@as Source]]) then
                addOocMessage(v, 'Proximity OOC', source, message)
                logger.log({
                    source = 'qbx_core',
                    webhook  = 'ooc',
                    event = 'OOC',
                    color = 'white',
                    tags = config.logging.role,
                    message = ('**%s** (CitizenID: %s | ID: %s) **Message:** %s'):format(GetPlayerName(source), player.PlayerData.citizenid, source, message)
                })
            end
        end
    end
end)

function sanitizeTags(msg)
    return msg
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub('"', "&quot;")
        :gsub("'", "&apos;")
end

lib.addCommand('me', {
    help = locale('command.me.help'),
    params = {
        { name = locale('command.me.params.message.name'), help = locale('command.me.params.message.help'), type = 'string' }
    }
}, function(source, args)
    args[1] = args[locale('command.me.params.message.name')]
    args[locale('command.me.params.message.name')] = nil
    if #args < 1 then Notify(source, locale('error.missing_args2'), 'error') return end
    local msg = sanitizeTags(table.concat(args, ' '))
    local playerState = Player(source).state
    playerState:set('me', msg, true)

    -- We have to reset the playerState since the state does not get replicated on StateBagHandler if the value is the same as the previous one --
    playerState:set('me', nil, true)
end)

lib.addCommand('id', {help = locale('info.check_id')}, function(source)
    Notify(source, 'ID: ' .. source)
end)

