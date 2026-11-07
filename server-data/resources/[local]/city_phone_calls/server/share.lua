-- Sharing your contact with someone close (like AirDrop). The list of people nearby shows no names; the other person
-- gets a notification and saves the card only if they tap it.
local common = require 'server.common'
local store = require 'server.store'

local OFFER_SECONDS = 120

---@type table<integer, { from: integer, to: integer, name: string, number: string, at: integer }>
local offers = {}
local nextOffer = 0

local function distance(a, b)
    return #(GetEntityCoords(GetPlayerPed(a)) - GetEntityCoords(GetPlayerPed(b)))
end

-- People close enough to share with: only an id and how far, never who they are
lib.callback.register('city_phone_calls:nearby', function(source)
    local src = source
    if not common.player(src) or common.throttled(src, 'nearby', 1000) then return {} end

    local list = {}

    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)

        if target ~= src and common.hasPhone(target) then
            local meters = distance(src, target)
            if meters <= Config.ShareDistance then list[#list + 1] = { id = target, distance = math.floor(meters * 10) / 10 } end
        end
    end

    table.sort(list, function(a, b) return a.distance < b.distance end)

    return list
end)

lib.callback.register('city_phone_calls:share', function(source, target)
    local src = source
    local player, _, number = common.player(src)

    if not player or type(target) ~= 'number' or target == src or not GetPlayerName(target) then return false end
    if common.throttled(src, 'share', 5000) then return false, 'wait' end
    if distance(src, target) > Config.ShareDistance or not common.hasPhone(target) then return false, 'far' end

    local info = player.PlayerData.charinfo

    nextOffer = nextOffer + 1
    offers[nextOffer] = {
        from = src, to = target, number = number, at = os.time(),
        name = common.name(('%s %s'):format(info.firstname, info.lastname)) or number,
    }

    TriggerClientEvent('city_phone_calls:client:offer', target, nextOffer, offers[nextOffer].name, number)

    return true
end)

-- Tapping "Save" on the notification
lib.callback.register('city_phone_calls:acceptOffer', function(source, id)
    local src = source
    local _, citizenid = common.player(src)
    local offer = type(id) == 'number' and offers[id]

    if not citizenid or not offer or offer.to ~= src then return false end

    offers[id] = nil
    if os.time() - offer.at > OFFER_SECONDS then return false, 'expired' end
    if store.countContacts(citizenid) >= Config.MaxContacts then return false, 'full' end

    return store.addContact(citizenid, offer.name, offer.number, false) ~= nil, offer.name
end)

-- Old offers are dropped every few minutes
CreateThread(function()
    while true do
        Wait(OFFER_SECONDS * 1000)

        local now = os.time()
        for id, offer in pairs(offers) do
            if now - offer.at > OFFER_SECONDS then offers[id] = nil end
        end
    end
end)
