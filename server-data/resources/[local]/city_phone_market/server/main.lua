-- The Market's server side: listing and searching ads, publishing (with the fee), editing, renewing, deleting,
-- favorites, the seller's number for Messages, and staff removing an ad. Every callback works on the caller's own
-- character; prices, categories and texts are checked here.
local store = require 'server.store'

local PURGE_MS = 3600000
local PHOTO_URI = '^data:image/%a+;base64,[%w%+/=]+$'

local last = {}

CreateThread(function()
    store.init()

    while true do
        store.purge()
        Wait(PURGE_MS)
    end
end)

---@param src integer
---@return string? citizenid
---@return string? number
local function owner(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    return player.PlayerData.citizenid, tostring(player.PlayerData.charinfo.phone or '')
end

---true when the same action came too soon after the last one
local function throttled(src, key, ms)
    local now = GetGameTimer()
    local byKey = last[src] or {}

    last[src] = byKey
    if byKey[key] and now - byKey[key] < ms then return true end

    byKey[key] = now
    return false
end

---A whole number from the page (JSON numbers can arrive as 5.0)
---@return integer?
local function int(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

local function hasPhone(src)
    return exports.city_inventory:GetItemCount(src, Config.Item) > 0
end

local function isStaff(src)
    return IsPlayerAceAllowed(tostring(src), Config.StaffAce)
end

---@param value unknown
---@param max integer
---@param allowEmpty boolean?
---@return string?
local function text(value, max, allowEmpty)
    if type(value) ~= 'string' then return end

    -- control characters and < > go; new lines stay (descriptions)
    local clean = value:gsub('[\0-\9\11-\31<>]', ''):match('^%s*(.-)%s*$')
    if #clean < 1 and not allowEmpty then return end

    return clean:sub(1, max)
end

local function isCategory(value)
    for _, category in ipairs(Config.Categories) do
        if category == value then return true end
    end

    return false
end

---The ad form as sent by the page, checked. Returns nil when something is wrong.
---@param data unknown
local function readAd(data)
    if type(data) ~= 'table' then return end

    local title = text(data.title, Config.TitleLength)
    local description = text(data.description, Config.DescriptionLength, true)
    local price = int(data.price)

    if not title or not description or not isCategory(data.category) then return end
    if not price or price < 0 or price > Config.MaxPrice then return end

    title = title:gsub('\n', ' ')

    return { title = title, description = description, price = price, category = data.category, show_number = data.showNumber == true }
end

---The image of one of the player's photos (city_phone_photos), if a valid id is given
---@return string? photo
---@return boolean ok false when the id is not one of their photos
local function photoOf(citizenid, id)
    if id == nil then return nil, true end
    id = int(id)
    if not id then return nil, false end

    local data = exports.city_phone_photos:Data(citizenid, id)
    if type(data) ~= 'string' or not data:find(PHOTO_URI) then return nil, false end

    return data, true
end

---What a page may see of an ad: the number only if the seller shows it, never the owner's citizenid
local function view(ad, citizenid, favorites)
    return {
        id = ad.id,
        title = ad.title,
        description = ad.description,
        price = ad.price,
        category = ad.category,
        number = ad.show_number and ad.number or nil,
        showNumber = ad.show_number,
        hasPhoto = ad.has_photo,
        createdAt = ad.created_at,
        expiresAt = ad.expires_at,
        mine = ad.citizenid == citizenid,
        favorite = favorites and favorites[ad.id] == true or false,
    }
end

local function viewAll(rows, citizenid)
    local favorites = {}
    for _, id in ipairs(store.favoriteIds(citizenid)) do favorites[id] = true end

    local list = {}
    for i = 1, #rows do list[i] = view(rows[i], citizenid, favorites) end

    return list
end

lib.callback.register('city_phone_market:list', function(source, category, search, before)
    local src = source
    local citizenid = owner(src)
    if not citizenid or throttled(src, 'list', 250) then return end

    category = isCategory(category) and category or nil
    search = text(search, 30)
    before = int(before)

    return {
        ads = viewAll(store.list(category, search, before), citizenid),
        staff = isStaff(src),
        fee = Config.Fee,
        days = Config.Days,
    }
end)

lib.callback.register('city_phone_market:mine', function(source)
    local src = source
    local citizenid = owner(src)
    if not citizenid or throttled(src, 'mine', 250) then return end

    return { ads = viewAll(store.mine(citizenid), citizenid), max = Config.MaxAds, fee = Config.Fee, days = Config.Days }
end)

lib.callback.register('city_phone_market:favorites', function(source)
    local src = source
    local citizenid = owner(src)
    if not citizenid or throttled(src, 'favorites', 250) then return end

    return viewAll(store.favorites(citizenid), citizenid)
end)

lib.callback.register('city_phone_market:photo', function(source, id)
    local src = source
    id = int(id)
    if not owner(src) or not id then return end

    return store.photo(id)
end)

-- The player's own photos to pick one for an ad: ids only, then each image when shown
lib.callback.register('city_phone_market:myPhotos', function(source)
    local src = source
    local citizenid = owner(src)
    if not citizenid then return end

    local list = {}
    for _, photo in ipairs(exports.city_phone_photos:List(citizenid)) do
        list[#list + 1] = photo.id
        if #list >= Config.PhotoPicker then break end
    end

    return list
end)

lib.callback.register('city_phone_market:myPhoto', function(source, id)
    local src = source
    id = int(id)
    local citizenid = owner(src)
    if not citizenid or not id then return end

    return exports.city_phone_photos:Data(citizenid, id)
end)

lib.callback.register('city_phone_market:publish', function(source, data, photoId)
    local src = source
    local citizenid, number = owner(src)
    if not citizenid or not hasPhone(src) or throttled(src, 'write', 2000) then return false, 'invalid' end

    local ad = readAd(data)
    if not ad then return false, 'invalid' end

    local photo, photoOk = photoOf(citizenid, photoId)
    if not photoOk then return false, 'invalid' end
    if store.countActive(citizenid) >= Config.MaxAds then return false, 'limit' end

    if not exports.qbx_core:RemoveMoney(src, 'bank', Config.Fee, 'market-ad') then return false, 'no_money' end

    ad.citizenid, ad.number, ad.photo = citizenid, number, photo

    return store.add(ad) ~= nil
end)

-- Editing is free and keeps the dates; photoId: a new photo, false to remove it, nil to keep it
lib.callback.register('city_phone_market:edit', function(source, id, data, photoId)
    local src = source
    id = int(id)
    local citizenid = owner(src)
    if not citizenid or not id or throttled(src, 'write', 2000) then return false, 'invalid' end

    local ad = readAd(data)
    if not ad then return false, 'invalid' end

    if photoId == nil then return store.update(citizenid, id, ad, true) end
    if photoId == false then return store.update(citizenid, id, ad, false) end

    local photo, photoOk = photoOf(citizenid, photoId)
    if not photoOk or not photo then return false, 'invalid' end

    ad.photo = photo
    return store.update(citizenid, id, ad, false)
end)

lib.callback.register('city_phone_market:renew', function(source, id)
    local src = source
    id = int(id)
    local citizenid = owner(src)
    if not citizenid or not id or throttled(src, 'write', 2000) then return false, 'invalid' end

    local ad = store.get(id)
    if not ad or ad.citizenid ~= citizenid then return false, 'invalid' end

    -- An expired ad coming back counts against the limit again
    if ad.expires_at <= os.time() and store.countActive(citizenid) >= Config.MaxAds then return false, 'limit' end
    if not exports.qbx_core:RemoveMoney(src, 'bank', Config.Fee, 'market-ad') then return false, 'no_money' end

    return store.renew(citizenid, id)
end)

lib.callback.register('city_phone_market:delete', function(source, id)
    local src = source
    id = int(id)
    local citizenid = owner(src)
    if not citizenid or not id or throttled(src, 'write', 1000) then return false end

    return store.delete(id, citizenid)
end)

lib.callback.register('city_phone_market:staffRemove', function(source, id)
    local src = source
    id = int(id)
    if not owner(src) or not id then return false end

    if not isStaff(src) then
        lib.print.warn(('city_phone_market: %s tried to remove ad %s without %s'):format(src, id, Config.StaffAce))
        return false
    end

    local ad = store.get(id)
    if not ad or not store.delete(id) then return false end

    if GetResourceState('city_staff') == 'started' then
        exports.city_staff:Log(src, 'market_remove', { citizenid = ad.citizenid }, ('#%d %s'):format(ad.id, ad.title))
    end

    return true
end)

lib.callback.register('city_phone_market:favorite', function(source, id, favorite)
    local src = source
    id = int(id)
    local citizenid = owner(src)
    if not citizenid or not id or throttled(src, 'favorite', 300) then return false end
    if favorite and not store.get(id) then return false end

    return store.setFavorite(citizenid, id, favorite == true)
end)

-- "Contact": the seller's number goes only to the buyer's Messages, which opens the chat
lib.callback.register('city_phone_market:contact', function(source, id)
    local src = source
    id = int(id)
    local citizenid = owner(src)
    if not citizenid or not id or not hasPhone(src) then return end

    local ad = store.get(id)
    if not ad or ad.citizenid == citizenid or ad.expires_at <= os.time() then return end

    return ad.number
end)

AddEventHandler('playerDropped', function()
    last[source] = nil
end)
