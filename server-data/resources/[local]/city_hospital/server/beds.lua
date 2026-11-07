-- Hospital beds: who lies in which, and the treatment timer. A bed is claimed on the server, so two players can't share
-- one and nobody gets healed faster than the treatment time.
local charges = require 'server.charges'
local settings = require 'server.config'

local beds = {}

---@type table<string, table<integer, integer>> hospital -> bed index -> source
local taken = {}
---@type table<integer, { hospital: string, bed: integer, since: integer, paid: boolean, wait: integer }>
local lying = {}

for name in pairs(Config.Hospitals) do taken[name] = {} end

---@param hospital string
---@return integer? bed
function beds.free(hospital)
    local list = Config.Hospitals[hospital] and Config.Hospitals[hospital].beds or {}

    for i = 1, #list do
        if not taken[hospital][i] then return i end
    end
end

---@param src integer
---@return string hospital
function beds.nearestHospital(src)
    local coords = GetEntityCoords(GetPlayerPed(src))
    local best, bestDistance = 'pillbox', math.huge

    for name, hospital in pairs(Config.Hospitals) do
        local distance = #(coords - hospital.blip)
        if distance < bestDistance then best, bestDistance = name, distance end
    end

    return best
end

---Puts a player in a bed. paid = the fee was already taken (respawn, reception).
---@param src integer
---@param hospital string
---@param bed integer
---@param paid boolean
---@param wait integer seconds of treatment
---@return boolean
function beds.claim(src, hospital, bed, paid, wait)
    if lying[src] or not taken[hospital] or taken[hospital][bed] then return false end

    taken[hospital][bed] = src
    lying[src] = { hospital = hospital, bed = bed, since = os.time(), paid = paid, wait = wait }

    return true
end

---@param src integer
function beds.release(src)
    local info = lying[src]
    if not info then return end

    taken[info.hospital][info.bed] = nil
    lying[src] = nil
end

---@param src integer
---@return table?
function beds.of(src)
    return lying[src]
end

---Heals the player once the treatment time has passed; charges the bed fee unless it was paid already
---@param src integer
---@return boolean
function beds.finish(src)
    local info = lying[src]
    if not info or info.healed or os.time() - info.since < info.wait then return false end

    info.healed = true

    if not info.paid then charges.take(src, settings.prices.bed, 'hospital-bed', 'Hospital bed') end

    exports.qbx_medical:Heal(src)

    return true
end

AddEventHandler('playerDropped', function()
    beds.release(source)
end)

return beds
