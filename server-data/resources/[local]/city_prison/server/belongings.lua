-- What an inmate carries: kept in their prison locker on the way in, given back at the release desk. Illegal items and
-- weapons not registered to them go to the police evidence locker instead, for good. Cash never moves (it is the
-- player's ledger balance, see city_inventory/server/cashflow.lua).

local settings = require 'server.config'

local LOCKER = 'city_prison_locker'

local belongings = {}

local illegalNames = {}
for _, name in ipairs(settings.illegal.names) do illegalNames[name:lower()] = true end

exports.city_inventory:RegisterStash(LOCKER, locale('locker'), settings.lockerSlots, settings.lockerWeight, true, { [Config.PoliceJob] = 0 })

local function lockerOf(citizenid)
    return { id = LOCKER, owner = citizenid }
end

---Serials of the weapons registered to this character in the MDT
---@param citizenid string
---@return table<string, true>
local function registeredSerials(citizenid)
    if GetResourceState('city_police') ~= 'started' then return {} end

    return exports.city_police:RegisteredWeapons(citizenid) or {}
end

---@param item table slot data
---@param serials table<string, true>
---@return boolean
local function isIllegal(item, serials)
    local name = item.name:lower()
    if illegalNames[name] then return true end

    for _, pattern in ipairs(settings.illegal.patterns) do
        if name:find(pattern) then return true end
    end

    if name:find('^weapon_') then
        local serial = type(item.metadata) == 'table' and item.metadata.serial
        return not (type(serial) == 'string' and serials[serial])
    end

    return false
end

---Moves one slot to an inventory: added there first, then taken from the player, so nothing is lost if it doesn't fit
local function move(src, item, to)
    if not exports.city_inventory:AddItem(to, item.name, item.count, item.metadata) then return false end

    if not exports.city_inventory:RemoveItem(src, item.name, item.count, item.metadata, item.slot) then
        lib.print.error(('city_prison: %s x%d added to %s but not removed from %s'):format(item.name, item.count, json.encode(to), src))
    end

    return true
end

---On the way in: legal things to the locker, the rest to the evidence locker
---@param src integer
---@param citizenid string
---@return integer seized how many slots went to evidence
function belongings.confiscate(src, citizenid)
    local items = exports.city_inventory:GetInventoryItems(src)
    if not items then return 0 end

    local serials = registeredSerials(citizenid)
    local locker = lockerOf(citizenid)
    local seized = 0

    for _, item in pairs(items) do
        if item.name ~= settings.cashItem then
            local toEvidence = isIllegal(item, serials) and GetResourceState('city_police') == 'started'

            if toEvidence and move(src, item, settings.evidenceStash) then
                seized = seized + 1
            elseif not move(src, item, locker) then
                lib.print.warn(('city_prison: could not keep %s x%d of %s'):format(item.name, item.count, citizenid))
            end
        end
    end

    return seized
end

---What is left in a character's locker (slots)
---@param citizenid string
---@return integer
function belongings.count(citizenid)
    local items = exports.city_inventory:GetInventoryItems(lockerOf(citizenid))
    local count = 0

    for _ in pairs(items or {}) do count = count + 1 end

    return count
end

---Gives back what fits; the rest waits in the locker
---@param src integer
---@param citizenid string
---@return boolean all everything was given back
function belongings.giveBack(src, citizenid)
    local locker = lockerOf(citizenid)
    local items = exports.city_inventory:GetInventoryItems(locker)
    local all = true

    for _, item in pairs(items or {}) do
        if exports.city_inventory:AddItem(src, item.name, item.count, item.metadata) then
            exports.city_inventory:RemoveItem(locker, item.name, item.count, item.metadata, item.slot)
        else
            all = false
        end
    end

    return all
end

---Leaving prison: whatever was made or found inside stays inside (cash is kept)
---@param src integer
function belongings.clearPrisonItems(src)
    exports.city_inventory:ClearInventory(src, settings.cashItem)
end

return belongings
