-- The photo tool (started from the Staff app): the staff member's client dresses its ped one piece at a time and asks
-- for each picture here; the server captures it with screencapture and keeps it in the tab's pack (server/images.lua).
-- A run can be every piece, or one tab, one sex and a range of numbers (e.g. the 30 new jackets).
local images = require 'server.images'
local catalog = require 'shared.tattoos'

local DATA_URI = '^data:image/webp;base64,[%w%+/=]+$'
local MAX_DATA_LENGTH = 2 * 1024 * 1024
local MAX_DRAWABLE = 2000
local BUCKET_BASE = 7700

---@type table<integer, { bucket: integer, taken: integer, from: integer }>
local sessions = {}

local CATEGORIES = {}
for _, storeType in ipairs({ 'clothing', 'barber', 'tattoo' }) do
    for _, category in ipairs(Config.Categories[storeType]) do CATEGORIES[category.id] = category end
end

-- Keys a picture may have: c<component>, p<prop>, o<overlay>, from the categories the shops sell
local KEYS = {}
for _, list in pairs(Config.Categories) do
    for _, category in ipairs(list) do
        if category.kind == 'tattoo' then
            KEYS['t' .. category.id] = category
        else
            local prefix = (category.kind == 'prop' and 'p') or (category.kind == 'overlay' and 'o') or 'c'
            KEYS[prefix .. category.slot] = category
        end
    end
end

local function capture(src)
    local result = promise.new()

    exports.screencapture:serverCapture(src, {
        encoding = 'webp',
        maxWidth = Config.Photos.width,
        maxHeight = Config.Photos.height,
    }, function(data)
        result:resolve(data)
    end, 'base64')

    SetTimeout(10000, function()
        if result.state == 0 then result:resolve(nil) end
    end)

    return Citizen.Await(result)
end

local function staffLog(src, details)
    if GetResourceState('city_staff') ~= 'started' then return end
    exports.city_staff:Log(src, 'clothing_photos', nil, details)
end

---Shop numbers (as on the cards, from 1) to a style range; nil and why for bad input
local function readOptions(data)
    data = type(data) == 'table' and data or {}

    local category = data.category or 'all'
    if category ~= 'all' and not CATEGORIES[category] then return nil, 'invalid' end

    local sex = data.sex or 'both'
    if sex ~= 'both' and sex ~= 'm' and sex ~= 'f' then return nil, 'invalid' end

    local function number(value)
        if value == nil then return nil, true end
        local n = math.tointeger(value)
        if not n or n < 1 or n > MAX_DRAWABLE + 1 then return nil, false end
        return n - 1, true
    end

    local from, okFrom = number(data.from)
    local to, okTo = number(data.to)
    if not okFrom or not okTo then return nil, 'bad_range' end
    if from and to and from > to then return nil, 'bad_range' end

    return {
        category = category,
        sex = sex,
        from = from or 0,
        to = to or MAX_DRAWABLE,
        overwrite = data.overwrite == true,
    }
end

---The tabs the Staff app offers
exports('PhotoCategories', function()
    local list = {}
    for _, storeType in ipairs({ 'clothing', 'barber', 'tattoo' }) do
        for _, category in ipairs(Config.Categories[storeType]) do
            list[#list + 1] = { id = category.id, label = category.label }
        end
    end
    return list
end)

---Starts the tool for a staff member (called by city_staff after its own permission check)
---@param src integer
---@param data table? { category, sex, from, to, overwrite } from the Staff app
---@return boolean ok
---@return string? reason
local function start(src, data)
    if not exports.qbx_core:GetPlayer(src) then return false, 'player' end
    if not IsPlayerAceAllowed(tostring(src), Config.PhotoAce) then return false, 'no_permission' end
    if sessions[src] then return false, 'busy' end
    if GetResourceState('screencapture') ~= 'started' then return false, 'screencapture' end

    local options, reason = readOptions(data)
    if not options then return false, reason end

    sessions[src] = { bucket = BUCKET_BASE + src, taken = 0, from = GetPlayerRoutingBucket(src) }
    SetPlayerRoutingBucket(src, sessions[src].bucket)
    TriggerClientEvent('city_clothing:client:photos', src, options)
    staffLog(src, ('started the clothing photo tool: %s, %s, #%d-#%d%s'):format(options.category, options.sex,
        options.from + 1, options.to + 1, options.overwrite and ', overwrite' or ''))

    return true
end

exports('StartPhotos', start)

-- The styles of a tab that already have a picture, so the tool skips them
lib.callback.register('city_clothing:photos:have', function(source, sex, key)
    if not sessions[source] or (sex ~= 'm' and sex ~= 'f') or not KEYS[key] then return nil end

    local list = {}
    for style in pairs(images.have(sex, key)) do list[#list + 1] = style end
    return list
end)

lib.callback.register('city_clothing:photos:shot', function(source, sex, key, drawable)
    local src = source
    local session = sessions[src]
    if not session then return false end

    if (sex ~= 'm' and sex ~= 'f') or not KEYS[key] then return false end

    -- Tattoo pictures are keyed by a tattoo of that zone this sex can get; the rest by style number
    local category = KEYS[key]
    if category.kind == 'tattoo' then
        local entry = type(drawable) == 'string' and catalog.get(drawable)
        if not entry or entry.zone ~= category.zone or not catalog.hashFor(entry, sex) then return false end
    else
        drawable = math.tointeger(drawable)
        if not drawable or drawable < 0 or drawable > MAX_DRAWABLE then return false end
    end

    local data = capture(src)
    if type(data) ~= 'string' or #data > MAX_DATA_LENGTH or not data:find(DATA_URI) then
        lib.print.warn(('city_clothing: photo %s_%s_%s from %s failed'):format(sex, key, drawable, src))
        return false
    end

    images.add(sex, key, drawable, data)
    session.taken = session.taken + 1

    return true
end)

local function finish(src)
    local session = sessions[src]
    if not session then return 0 end

    sessions[src] = nil
    images.saveAll()
    if GetPlayerName(src) then SetPlayerRoutingBucket(src, session.from or 0) end
    staffLog(src, ('clothing photo tool finished: %d new pictures'):format(session.taken))

    return session.taken
end

lib.callback.register('city_clothing:photos:finish', function(source)
    return finish(source)
end)

AddEventHandler('playerDropped', function()
    finish(source)
end)
