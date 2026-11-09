-- Charging a person from the penal code: a fine (bank bill) or an arrest (booking photo, fingerprint, months). Totals
-- always come from shared/penal.lua here, never from the page.

local mdt = require 'server.mdt.core'
local police = require 'server.police'
local records = require 'server.records'
local settings = require 'server.config'

---@param photo unknown
---@return string?
local function photoOf(photo)
    if type(photo) ~= 'string' or #photo > settings.maxPhotoBytes then return end
    if not photo:match('^data:image/png;base64,[%w%+/=]+$') then return end

    return photo
end

---@param src integer officer
---@param target integer
---@param totals table
---@param charges table
local function bill(src, target, totals, charges)
    if totals.fine <= 0 then return true end

    local titles = {}
    for _, charge in ipairs(charges) do titles[#titles + 1] = charge.title end

    local label = locale('fine_bill', police.name(src), table.concat(titles, ', ')):sub(1, 120)
    local issuer = police.reach(src, target, 10.0) and src or nil

    return exports.city_bank:CreateBill(target, totals.fine, label, issuer)
end

---@param src integer officer
---@return boolean
local function atBookingPlace(src)
    if #settings.bookingPlaces == 0 then return true end

    for _, place in ipairs(settings.bookingPlaces) do
        if police.near(src, place.coords, place.radius) then return true end
    end

    return false
end

---Takes the driver licence away once the points reach the limit.
---@param target integer
---@param citizenid string
local function checkPoints(target, citizenid)
    if records.points(citizenid) < settings.maxPoints then return end

    local player = exports.qbx_core:GetPlayer(target)
    local licences = player and player.PlayerData.metadata.licences
    if not licences or not licences.driver then return end

    licences.driver = false
    exports.qbx_core:SetMetadata(target, 'licences', licences)
    police.notify(target, 'licence_suspended', 'error')
end

mdt.register('charge', function(src, data)
    local citizenid = mdt.citizenid(data.citizenid)
    local target = citizenid and exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if not target then return false, 'offline' end

    local targetSrc = target.PlayerData.source
    if targetSrc == src then return false, 'self' end

    local charges, totals = records.total(data.charges)
    if not charges then return false, 'invalid' end

    local kind = data.kind == 'arrest' and 'arrest' or 'fine'
    local notes = police.clean(data.notes, settings.text.line)
    local caseId = mdt.id(data.caseId)
    local photo, fingerprint

    if caseId and not MySQL.scalar.await('SELECT id FROM city_police_reports WHERE id = ?', { caseId }) then return false, 'not_found' end

    if kind == 'arrest' then
        if not police.reach(src, targetSrc, settings.chargeRange) then return false, 'too_far' end
        if not police.restrained(targetSrc) then return false, 'not_restrained' end
        if not atBookingPlace(src) then return false, 'not_at_station' end

        local months = records.reduce(totals.months, data.reduction)
        if not months then return false, 'invalid' end
        totals.months = months

        photo = photoOf(data.photo)
        fingerprint = target.PlayerData.metadata.fingerprint
    end

    if not bill(src, targetSrc, totals, charges) then return false, 'bill_failed' end

    local name = police.fullName(target)
    local officer = police.name(src)

    local id = records.add({
        citizenid = citizenid, name = name, kind = kind, charges = charges,
        months = kind == 'arrest' and totals.months or 0, fine = totals.fine, points = totals.points,
        notes = notes ~= '' and notes or nil, officer = officer, officerCid = police.citizenid(src),
        photo = photo, fingerprint = fingerprint, caseId = caseId,
    })

    if totals.points > 0 then checkPoints(targetSrc, citizenid) end

    if kind == 'arrest' then
        records.serveWarrants(citizenid, officer)

        -- Straight to Bolingbroke (city_prison adds any time owed from an escape)
        if totals.months > 0 and GetResourceState('city_prison') == 'started' then
            exports.city_prison:Jail(targetSrc, totals.months, officer)
        end

        local titles = {}
        for _, charge in ipairs(charges) do
            titles[#titles + 1] = charge.count > 1 and ('%s x%d'):format(charge.title, charge.count) or charge.title
        end

        TriggerClientEvent('city_police:client:arrested', targetSrc, { months = totals.months, fine = totals.fine, charges = titles, officer = officer })
    else
        police.notify(targetSrc, 'fined_you', 'error', totals.fine)
    end

    return true, { id = id, months = kind == 'arrest' and totals.months or 0, fine = totals.fine }
end)

-- Players near the officer, for the charge form ("who is in front of me")
mdt.register('nearby', function(src)
    local list = {}
    local coords = GetEntityCoords(GetPlayerPed(src))

    for target, player in pairs(exports.qbx_core:GetQBPlayers()) do
        if target ~= src and #(GetEntityCoords(GetPlayerPed(target)) - coords) <= settings.chargeRange then
            list[#list + 1] = { id = target, citizenid = player.PlayerData.citizenid, name = police.fullName(player) }
        end
    end

    return true, list
end, 'charge')

-- The Prison tab: who is in Bolingbroke now (city_prison's computer still changes and ends sentences)
mdt.register('inmates', function()
    return true, mdt.inmates()
end, 'charge')
