-- Frenzies: for a while one spot only gives one species, and it bites twice as fast. Shown to everyone through
-- GlobalState.fishingFrenzy (coords, radius, label, end time).
local settings = require 'server.config'
local fish = require 'server.fish'
local catch = require 'server.catch'
local util = require 'server.util'

local frenzy = {}

local current

---Species that could frenzy at a spot now: real fish of that region, not legendary, in their hours.
---@param region string
---@return table[]
local function candidates(region)
    local hour = util.hour()
    local list = {}

    for _, entry in ipairs(fish.list) do
        if entry.kind == 'fish' and not entry.legendary and entry.regionSet[region] and catch.hourMatches(entry.hours, hour) then
            list[#list + 1] = entry
        end
    end

    return list
end

---@param spotIndex? integer a spot from server config, random when nil
---@return boolean
function frenzy.start(spotIndex)
    local spots = settings.frenzy.spots
    local spot = spots[spotIndex or math.random(#spots)]
    if not spot then return false end

    local list = candidates(spot.region)
    if #list == 0 then return false end

    local entry = list[math.random(#list)]
    local minutes = math.random(settings.frenzy.minutes[1], settings.frenzy.minutes[2])

    current = { spot = spot, species = entry.name, endsAt = os.time() + minutes * 60 }

    GlobalState.fishingFrenzy = {
        coords = spot.coords,
        radius = spot.radius,
        label = entry.label,
        endsAt = current.endsAt,
    }

    TriggerClientEvent('city_fishing:client:announce', -1, 'frenzy_started', entry.label)

    return true
end

function frenzy.stop()
    current = nil
    GlobalState.fishingFrenzy = nil
end

---Runs every minute from events.lua.
function frenzy.tick()
    if current and os.time() >= current.endsAt then frenzy.stop() end
end

---Every checkMinutes: maybe start one.
function frenzy.roll()
    if current then return end
    if math.random() < settings.frenzy.chance then frenzy.start() end
end

---The frenzy species if the bobber is inside the active frenzy.
---@param bobber vector3
---@param region string
---@return string?
function frenzy.speciesAt(bobber, region)
    if not current or os.time() >= current.endsAt or current.spot.region ~= region then return end
    if #(bobber.xy - current.spot.coords.xy) > current.spot.radius then return end

    return current.species
end

return frenzy
