-- Taking a photo (asked by the Camera app) and the Photos app's library. The picture is captured here through
-- screencapture, so the client never sends an image of its own; size, count and cooldown are checked here.
local store = require 'server.store'

CreateThread(store.init)

local DATA_URI = '^data:image/webp;base64,[%w%+/=]+$'
local busy = {}
local lastPhoto = {}

---@return string? citizenid
local function owner(src)
    local player = exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData.citizenid or nil
end

local function capture(src)
    local result = promise.new()

    exports.screencapture:serverCapture(src, {
        encoding = Config.Capture.encoding,
        maxWidth = Config.Capture.maxWidth,
        maxHeight = Config.Capture.maxHeight,
    }, function(data)
        result:resolve(data)
    end, 'base64')

    -- A player who never answers doesn't block their camera forever
    SetTimeout(10000, function()
        if result.state == 0 then result:resolve(nil) end
    end)

    return Citizen.Await(result)
end

lib.callback.register('city_phone_photos:capture', function(source)
    local src = source
    local citizenid = owner(src)
    if not citizenid or busy[src] then return false, 'busy' end

    local now = GetGameTimer()
    if lastPhoto[src] and now - lastPhoto[src] < Config.Cooldown * 1000 then return false, 'busy' end
    if exports.city_inventory:GetItemCount(src, Config.Item) < 1 then return false, 'no_phone' end
    if store.count(citizenid) >= Config.MaxPhotos then return false, 'full' end

    busy[src], lastPhoto[src] = true, now
    local data = capture(src)
    busy[src] = nil

    if type(data) ~= 'string' or #data > Config.MaxDataLength or not data:find(DATA_URI) then
        lib.print.warn(('city_phone_photos: bad capture from %s (%s chars)'):format(src, type(data) == 'string' and #data or 0))
        return false, 'failed'
    end

    return store.add(citizenid, data), Config.MaxPhotos - store.count(citizenid)
end)

lib.callback.register('city_phone_photos:list', function(source)
    local citizenid = owner(source)
    if not citizenid then return end

    return { photos = store.list(citizenid), max = Config.MaxPhotos }
end)

-- One image (the gallery, the viewer, the wallpaper); only your own
lib.callback.register('city_phone_photos:photo', function(source, id)
    local citizenid = owner(source)
    id = math.tointeger(id)
    if not citizenid or not id then return end

    return store.data(citizenid, id)
end)

lib.callback.register('city_phone_photos:favorite', function(source, id, favorite)
    local citizenid = owner(source)
    id = math.tointeger(id)
    if not citizenid or not id then return false end

    return store.setFavorite(citizenid, id, favorite == true)
end)

lib.callback.register('city_phone_photos:delete', function(source, id)
    local citizenid = owner(source)
    id = math.tointeger(id)
    if not citizenid or not id then return false end

    return store.delete(citizenid, id)
end)

AddEventHandler('playerDropped', function()
    busy[source], lastPhoto[source] = nil, nil
end)
