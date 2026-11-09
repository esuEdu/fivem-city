-- Corner selling to locals. The server checks the local is real and close, rolls the offer and keeps it until the
-- player answers; the client only says which local and whether the offer is taken.
local settings = require 'server.config'
local common = require 'server.common'
local rules = require 'server.rules'

local corner = settings.corner
local PURGE_MS = 5 * 60 * 1000

---@type table<integer, { netId: integer, item: string, amount: integer, total: integer, expiresAt: integer }>
local offers = {}
---@type table<integer, integer>
local lastAsk = {}
---@type table<integer, integer> net id -> os.time() the local buys again
local usedPeds = {}

---The local's entity, if it is a real non-player ped next to the player
---@return integer?
local function localPed(src, netId)
    if not math.tointeger(netId) then return end

    local ped = NetworkGetEntityFromNetworkId(netId)
    if not ped or ped == 0 or not DoesEntityExist(ped) or GetEntityType(ped) ~= 1 or IsPedAPlayer(ped) then return end
    if not common.near(src, GetEntityCoords(ped), Config.UseDistance + 1.5) then return end

    return ped
end

lib.callback.register('city_drugs:corner:ask', function(source, netId)
    local src = source
    if not common.player(src) then return false end

    local now = os.time()
    if lastAsk[src] and now - lastAsk[src] < corner.playerCooldown then return false, 'wait' end
    lastAsk[src] = now

    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return false end

    local ped = localPed(src, netId)
    if not ped then return false end

    if usedPeds[netId] and usedPeds[netId] > now then return false, 'used' end
    if not common.enoughPolice('corner') then return false, 'quiet' end

    local offer = rules.offer(common.counts(src, Config.CornerItems), corner.prices, math.random)
    if not offer then return false, 'nothing' end

    usedPeds[netId] = now + corner.pedCooldownMinutes * 60

    if rules.chance(corner.refuseChance, math.random) then
        common.alert(offer.drug, 'refuse', locale('alert_corner'), GetEntityCoords(ped))

        return true, { refused = true }
    end

    offer.netId = netId
    offer.expiresAt = now + corner.offerSeconds
    offers[src] = offer

    local item = exports.city_inventory:Items(offer.item)

    return true, { label = item and item.label or offer.item, amount = offer.amount, total = offer.total }
end)

lib.callback.register('city_drugs:corner:sell', function(source)
    local src = source
    local offer = offers[src]
    offers[src] = nil

    if not offer or os.time() > offer.expiresAt then return false end
    if not common.player(src) then return false end

    local ped = localPed(src, offer.netId)
    if not ped then return false end

    if exports.city_inventory:GetItemCount(src, offer.item) < offer.amount then return false, 'missing' end

    local ok, err = common.exchange(src, { [offer.item] = offer.amount }, { [settings.payItem] = offer.total })
    if not ok then return false, err or 'missing' end

    common.record(src, 'sale', offer.drug, offer.total)
    common.alert(offer.drug, 'sale', locale('alert_corner'), GetEntityCoords(ped), offer.total)

    return true, offer.total
end)

RegisterNetEvent('city_drugs:server:declineOffer', function()
    offers[source] = nil
end)

AddEventHandler('playerDropped', function()
    offers[source] = nil
    lastAsk[source] = nil
end)

CreateThread(function()
    while true do
        Wait(PURGE_MS)

        local now = os.time()

        for netId, buysAt in pairs(usedPeds) do
            if now >= buysAt then usedPeds[netId] = nil end
        end
    end
end)
