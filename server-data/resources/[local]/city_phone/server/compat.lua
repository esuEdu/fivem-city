-- Events scripts still send to the old QBCore phone (qb-phone). They become phone notifications until the matching app
-- exists. Only the player's own phone is reached: a client asking for a mail only gets it on its own screen.
local MAIL_COOLDOWN_MS = 1000
local lastMail = {}

---Mail buttons fire a client event on the player. Only these known ones are kept.
local MAIL_ACTIONS = {
    ['qb-drugs:client:setLocation'] = true,
}

---@param src integer
---@param mail unknown
local function sendMail(src, mail)
    if type(mail) ~= 'table' or type(mail.sender) ~= 'string' then return end

    local subject = type(mail.subject) == 'string' and mail.subject or ''
    local message = type(mail.message) == 'string' and mail.message or ''
    local button = type(mail.button) == 'table' and mail.button
    local action

    if button and MAIL_ACTIONS[button.buttonEvent] then
        action = { event = button.buttonEvent, data = button.buttonData }
    end

    TriggerClientEvent('city_phone:client:notify', src, {
        app = 'mail',
        title = mail.sender:sub(1, 60),
        text = (subject ~= '' and ('%s: %s'):format(subject, message) or message):sub(1, 300),
        action = action,
    })
end

RegisterNetEvent('qb-phone:server:sendNewMail', function(mail)
    local src = source
    local now = GetGameTimer()

    if lastMail[src] and now - lastMail[src] < MAIL_COOLDOWN_MS then return end
    lastMail[src] = now

    sendMail(src, mail)
end)

-- Server-only (qbx_vehiclesales): reaches the player if they are online; there is no mailbox to keep it in yet
AddEventHandler('qb-phone:server:sendNewMailToOffline', function(citizenid, mail)
    if type(citizenid) ~= 'string' then return end

    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if player then sendMail(player.PlayerData.source, mail) end
end)

AddEventHandler('playerDropped', function()
    lastMail[source] = nil
end)
