-- The photo tool (started from the Staff app): the staff member's client dresses its ped one piece at a time and asks
-- for each picture here; the server captures it with screencapture and writes images/<sex>_<key>_<drawable>.webp.
-- images/index.json lists what exists, so the shop knows which cards have a picture.
local RESOURCE = GetCurrentResourceName()
local INDEX_FILE = 'images/index.json'
local DATA_URI = '^data:image/webp;base64,([%w%+/=]+)$'
local MAX_DRAWABLE = 2000
local SAVE_INDEX_EVERY = 25
local BUCKET_BASE = 7700

---@type table<integer, { bucket: integer, taken: integer }>
local sessions = {}
local index = json.decode(LoadResourceFile(RESOURCE, INDEX_FILE) or '{}') or {}
local unsaved = 0

-- Keys a picture may have: c<component>, p<prop>, o<overlay>, from the categories the shops sell
local KEYS = {}
for _, list in pairs(Config.Categories) do
    for _, category in ipairs(list) do
        local prefix = (category.kind == 'prop' and 'p') or (category.kind == 'overlay' and 'o') or 'c'
        KEYS[prefix .. category.slot] = true
    end
end

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local DECODE = {}
for i = 1, #B64 do DECODE[B64:byte(i)] = i - 1 end

local function decodeBase64(data)
    if #data % 4 ~= 0 then return nil end

    local out, n = {}, 0

    for i = 1, #data, 4 do
        local b1, b2, b3, b4 = data:byte(i, i + 3)
        local a, b, c, d = DECODE[b1], DECODE[b2], DECODE[b3], DECODE[b4]
        if not a or not b then return nil end

        -- Arithmetic instead of bit operators so scripts/check.sh (luajit) can still parse this file
        local v = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
        n = n + 1
        out[n] = string.char(math.floor(v / 65536) % 256)
        if c then
            n = n + 1
            out[n] = string.char(math.floor(v / 256) % 256)
        end
        if d then
            n = n + 1
            out[n] = string.char(v % 256)
        end
    end

    return table.concat(out)
end

local function saveIndex()
    SaveResourceFile(RESOURCE, INDEX_FILE, json.encode(index), -1)
    unsaved = 0
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

---Starts the tool for a staff member (called by city_staff after its own permission check)
---@param src integer
---@return boolean ok
---@return string? reason
local function start(src)
    if not exports.qbx_core:GetPlayer(src) then return false, 'player' end
    if not IsPlayerAceAllowed(tostring(src), Config.PhotoAce) then return false, 'no_permission' end
    if sessions[src] then return false, 'busy' end
    if GetResourceState('screencapture') ~= 'started' then return false, 'screencapture' end

    sessions[src] = { bucket = BUCKET_BASE + src, taken = 0, from = GetPlayerRoutingBucket(src) }
    SetPlayerRoutingBucket(src, sessions[src].bucket)
    TriggerClientEvent('city_clothing:client:photos', src)
    staffLog(src, 'started the clothing photo tool')

    return true
end

exports('StartPhotos', start)

lib.callback.register('city_clothing:photos:index', function(source)
    if not sessions[source] then return nil end
    return index
end)

lib.callback.register('city_clothing:photos:shot', function(source, sex, key, drawable)
    local src = source
    local session = sessions[src]
    if not session then return false end

    if (sex ~= 'm' and sex ~= 'f') or not KEYS[key] then return false end
    drawable = math.tointeger(drawable)
    if not drawable or drawable < 0 or drawable > MAX_DRAWABLE then return false end

    local data = capture(src)
    local encoded = type(data) == 'string' and data:match(DATA_URI)
    local bytes = encoded and decodeBase64(encoded)
    if not bytes or #bytes == 0 then
        lib.print.warn(('city_clothing: photo %s_%s_%d from %s failed'):format(sex, key, drawable, src))
        return false
    end

    local name = ('%s_%s_%d'):format(sex, key, drawable)
    if not SaveResourceFile(RESOURCE, ('images/%s.webp'):format(name), bytes, #bytes) then return false end

    index[name] = true
    session.taken = session.taken + 1
    unsaved = unsaved + 1
    if unsaved >= SAVE_INDEX_EVERY then saveIndex() end

    return true
end)

local function finish(src)
    local session = sessions[src]
    if not session then return 0 end

    sessions[src] = nil
    saveIndex()
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
