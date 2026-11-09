-- Police searches need consent: a suspect who is cuffed, down or has their hands up is searched straight away; anyone
-- else gets an accept/refuse prompt. The openInventory hook stops an officer on duty opening a free person's
-- inventory without that consent (robbers and staff are still decided by city_inventory).

local police = require 'server.police'
local settings = require 'server.config'

---@type table<integer, { officer: integer, expires: integer }> target -> open request
local pending = {}
---@type table<integer, { target: integer, expires: integer }> officer -> consent to open once
local consents = {}
---@type table<integer, integer> officer -> last request time
local lastAsk = {}

local CONSENT_MS = 10000

---@param target integer
---@return boolean
local function canBeSearched(target)
    return police.restrained(target) or Player(target).state.handsup == true
end

lib.callback.register('city_police:search', function(source, target)
    local src = source
    if not police.onDuty(src) then return false end

    target = police.reach(src, target)
    if not target then return false, 'too_far' end

    if canBeSearched(target) then return true, 'open' end

    local now = GetGameTimer()
    local request = pending[target]
    if request and request.expires > now then return false, 'search_pending' end
    if lastAsk[src] and now - lastAsk[src] < settings.search.cooldown * 1000 then return false, 'search_cooldown' end

    lastAsk[src] = now
    local expires = now + settings.search.seconds * 1000
    pending[target] = { officer = src, expires = expires }

    TriggerClientEvent('city_police:client:searchRequest', target, police.name(src), settings.search.seconds)

    -- No answer in time counts as a refusal
    SetTimeout(settings.search.seconds * 1000 + 500, function()
        local open = pending[target]
        if not open or open.expires ~= expires then return end

        pending[target] = nil
        police.notify(src, 'search_no_answer', 'error')
    end)

    return true, 'asked'
end)

RegisterNetEvent('city_police:server:searchAnswer', function(accepted)
    local src = source
    local request = pending[src]
    if not request then return end

    pending[src] = nil
    if request.expires < GetGameTimer() then return end

    local officer = request.officer

    if accepted ~= true then
        police.notify(officer, 'search_refused', 'error')
        return
    end

    if not police.onDuty(officer) or not police.reach(officer, src) then
        police.notify(officer, 'error_too_far', 'error')
        return
    end

    consents[officer] = { target = src, expires = GetGameTimer() + CONSENT_MS }
    TriggerClientEvent('city_police:client:openSearch', officer, src)
end)

-- city_inventory runs this before opening a player's inventory to anyone but staff (and drops it when we stop)
exports.city_inventory:registerHook('openInventory', function(payload)
    if payload.inventoryType ~= 'player' then return true end

    local officer = payload.source
    if not police.onDuty(officer) then return true end

    local target = math.tointeger(tonumber(payload.inventoryId))
    if not target then return true end

    local consent = consents[officer]
    consents[officer] = nil

    if consent and consent.target == target and consent.expires > GetGameTimer() then return true end
    if canBeSearched(target) then return true end

    lib.print.warn(('city_police: %s (%s) opened a search on %s without consent'):format(GetPlayerName(officer), officer, target))

    return false
end)

AddEventHandler('playerDropped', function()
    local src = source
    pending[src] = nil
    consents[src] = nil
    lastAsk[src] = nil
end)
