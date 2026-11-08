-- The Fishing app on the iFruit tablet: profile, skill tree, collection, market prices and events. Every callback
-- works out the character from source; staff actions check the ACE again and go to the staff log.
local settings = require 'server.config'
local fish = require 'server.fish'
local levels = require 'shared.levels'
local profiles = require 'server.profiles'
local util = require 'server.util'
local demand = require 'server.demand'
local tournaments = require 'server.tournaments'
local frenzy = require 'server.frenzy'

local function registerApp()
    exports.city_os:RegisterApp({
        id = Config.App.id,
        label = Config.App.label,
        page = 'web/app/index.html',
        icon = Config.App.icon,
        order = Config.App.order,
    })
end

registerApp()

-- city_os forgets its apps when it restarts
AddEventHandler('onResourceStart', function(resource)
    if resource == 'city_os' then registerApp() end
end)

---@param src integer
---@return boolean
local function isStaff(src)
    return IsPlayerAceAllowed(tostring(src), settings.tournaments.staffAce) and exports.qbx_core:IsOptin(src)
end

lib.callback.register('city_fishing:app:profile', function(source)
    local src = source
    local _, citizenid = util.player(src)
    if not citizenid then return false end

    local profile = profiles.get(citizenid)
    local valid, expires = util.licence(src, citizenid)

    return true, {
        level = profile.level,
        max = levels.max,
        xp = profile.xp,
        from = levels.xpFor(profile.level),
        to = profile.level < levels.max and levels.xpFor(profile.level + 1) or nil,
        points = levels.points(profile.level) - levels.spent(profile.skills),
        skills = profile.skills,
        caught = profile.caught,
        legendaries = profile.legendaries,
        biggest = profile.biggest and { label = fish.byName[profile.biggest.species] and fish.byName[profile.biggest.species].label, size = profile.biggest.size } or nil,
        licence = { valid = valid, expires = expires, now = os.time() },
        staff = isStaff(src),
    }
end)

lib.callback.register('city_fishing:app:learn', function(source, id)
    local src = source
    local _, citizenid = util.player(src)
    if not citizenid or type(id) ~= 'string' then return false end

    local profile = profiles.get(citizenid)
    local ok, reason = levels.canLearn(profile.skills, profile.level, id)
    if not ok then return false, reason end

    profile.skills[id] = (profile.skills[id] or 0) + 1
    profiles.save(profile)

    return true, profile.skills
end)

lib.callback.register('city_fishing:app:collection', function(source)
    local _, citizenid = util.player(source)
    if not citizenid then return false end

    local caught = {}
    for _, row in ipairs(profiles.collection(citizenid)) do caught[row.species] = row end

    local list = {}

    for _, entry in ipairs(fish.list) do
        local row = caught[entry.name]

        -- Legendaries stay secret until caught; junk isn't collected
        if not entry.junk and (not entry.legendary or row) then
            list[#list + 1] = {
                name = entry.name,
                label = row and entry.label or nil,
                regions = entry.regions,
                legendary = entry.legendary ~= nil,
                kind = entry.kind,
                count = row and row.count or 0,
                best = row and row.best or 0,
                firstAt = row and row.first_at or nil,
            }
        end
    end

    local total = 0
    for _, entry in ipairs(fish.list) do
        if not entry.junk then total = total + 1 end
    end

    return true, { list = list, total = total }
end)

lib.callback.register('city_fishing:app:market', function(source)
    if not util.player(source) then return false end

    return true, demand.prices()
end)

lib.callback.register('city_fishing:app:events', function(source)
    local src = source
    local _, citizenid = util.player(src)
    if not citizenid then return false end

    local staffSpecies
    if isStaff(src) then
        staffSpecies = {}
        for _, entry in ipairs(fish.list) do
            if entry.kind == 'fish' and not entry.legendary then
                staffSpecies[#staffSpecies + 1] = { name = entry.name, label = entry.label }
            end
        end
        table.sort(staffSpecies, function(a, b) return a.label < b.label end)
    end

    local snapshot = tournaments.snapshot(citizenid)
    snapshot.frenzy = GlobalState.fishingFrenzy
    snapshot.staff = staffSpecies ~= nil
    snapshot.species = staffSpecies
    snapshot.maxMinutes = settings.tournaments.maxMinutes
    snapshot.now = os.time()

    return true, snapshot
end)

lib.callback.register('city_fishing:app:join', function(source)
    local src = source
    local _, citizenid = util.player(src)
    if not citizenid then return false end

    return tournaments.join(src, citizenid)
end)

lib.callback.register('city_fishing:app:startTournament', function(source, data)
    local src = source
    local _, citizenid = util.player(src)
    if not citizenid or not isStaff(src) then
        lib.print.warn(('Player %s tried to start a fishing tournament without permission'):format(src))
        return false, 'no_permission'
    end

    local clean = tournaments.clean(data)
    if not clean then return false, 'invalid' end
    if not tournaments.start(clean, citizenid) then return false, 'tournament_running' end

    if GetResourceState('city_staff') == 'started' then
        exports.city_staff:Log(src, 'fishing_tournament', nil, ('%s (%s, %s, %d min)'):format(clean.label, clean.mode, clean.region, clean.minutes))
    end

    return true
end)

lib.callback.register('city_fishing:app:startFrenzy', function(source)
    local src = source
    if not util.player(src) or not isStaff(src) then return false, 'no_permission' end

    frenzy.stop()
    if not frenzy.start() then return false, 'invalid' end

    if GetResourceState('city_staff') == 'started' then
        exports.city_staff:Log(src, 'fishing_frenzy', nil, GlobalState.fishingFrenzy and GlobalState.fishingFrenzy.label or nil)
    end

    return true
end)
