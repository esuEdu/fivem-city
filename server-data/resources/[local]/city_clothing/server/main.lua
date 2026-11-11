-- The shops on the server: who is in which store, buying (priced and checked here from the saved look) and outfits
local look = require 'shared.look'
local settings = require 'server.config'
local images = require 'server.images'
local catalog = require 'shared.tattoos'

local REASONS = { clothing = 'clothing-shop', barber = 'barber-shop', tattoo = 'tattoo-shop' }

-- Each store's categories split in two: single pieces (look.buy) and tattoo zones (look.buyTattoos)
local PIECES, TATTOOS = {}, {}
for storeType, list in pairs(Config.Categories) do
    PIECES[storeType], TATTOOS[storeType] = {}, {}
    for _, category in ipairs(list) do
        local target = category.kind == 'tattoo' and TATTOOS[storeType] or PIECES[storeType]
        target[#target + 1] = category
    end
end
local BUY_COOLDOWN_MS = 1000
local NAME_PATTERN = "^[%w][%w %-'_%.]*$"

---@type table<integer, integer> the store each player has open
local sessions = {}
local lastBuy = {}

local function warn(src, reason)
    lib.print.warn(('city_clothing: refused %s (%s)'):format(src, reason))
end

local function citizenOf(src)
    local player = exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData.citizenid or nil
end

local function near(src, store)
    local coords = GetEntityCoords(GetPlayerPed(src))
    return #(coords - store.coords.xyz) <= Config.UseDistance
end

---The store a player has open and is still standing in, or nil
local function storeOf(src, wantedType)
    local index = sessions[src]
    local store = index and Config.Stores[index]
    if not store or (wantedType and store.type ~= wantedType) then return nil end
    if not near(src, store) then return nil end
    return store
end

local function loadSkin(citizenid)
    local raw = MySQL.scalar.await('SELECT skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', { citizenid })
    local skin = raw and json.decode(raw)
    return type(skin) == 'table' and skin or nil
end

local function saveSkin(citizenid, skin)
    MySQL.update.await('UPDATE playerskins SET model = ?, skin = ? WHERE citizenid = ? AND active = 1', {
        skin.model, json.encode(skin), citizenid,
    })
end

local function outfits(citizenid, model)
    local rows = MySQL.query.await('SELECT id, outfitname FROM player_outfits WHERE citizenid = ? AND model = ? ORDER BY id', {
        citizenid, model,
    })

    local list = {}
    for i = 1, #rows do list[i] = { id = rows[i].id, name = rows[i].outfitname } end
    return list
end

local function pricesFor(storeType)
    local list = {}
    for _, category in ipairs(Config.Categories[storeType]) do
        list[category.id] = (category.kind == 'tattoo' and settings.prices.tattoo or settings.prices[category.id]) or 0
    end
    return list
end

lib.callback.register('city_clothing:open', function(source, index)
    local src = source
    local citizenid = citizenOf(src)
    local store = type(index) == 'number' and Config.Stores[index]
    if not citizenid or not store then return nil end
    if not near(src, store) then return warn(src, 'open: too far') end

    local skin = loadSkin(citizenid)
    if not look.sexOf(skin) then return nil end

    sessions[src] = index

    return {
        type = store.type,
        prices = pricesFor(store.type),
        outfits = store.type == 'clothing' and outfits(citizenid, skin.model) or nil,
        maxOutfits = Config.MaxOutfits,
        custom = images.customFor(look.sexOf(skin)),
    }
end)

lib.callback.register('city_clothing:close', function(source)
    sessions[source] = nil
    return true
end)

lib.callback.register('city_clothing:buy', function(source, wanted, account)
    local src = source
    local citizenid = citizenOf(src)
    if not citizenid then return false, 'player' end

    local store = storeOf(src)
    if not store then return false, 'far' end
    if not settings.accounts[account] then return false, 'account' end

    local now = GetGameTimer()
    if lastBuy[src] and now - lastBuy[src] < BUY_COOLDOWN_MS then return false, 'busy' end
    lastBuy[src] = now

    local skin = loadSkin(citizenid)
    if not skin then return false, 'skin' end

    local newSkin, changes, total = look.buy(skin, wanted, PIECES[store.type], {
        prices = settings.prices,
        blocked = settings.blocked,
    })

    if newSkin and #TATTOOS[store.type] > 0 then
        local tattooChanges, tattooTotal
        newSkin, tattooChanges, tattooTotal = look.buyTattoos(newSkin, type(wanted) == 'table' and wanted.tattoos or nil,
            TATTOOS[store.type], catalog, { prices = settings.prices, maxPerZone = Config.MaxTattoosPerZone })

        if newSkin then
            for _, change in ipairs(tattooChanges) do changes[#changes + 1] = change end
            total = total + tattooTotal
        else
            changes = tattooChanges
        end
    end

    if not newSkin then
        warn(src, ('buy: %s'):format(changes))
        return false, 'invalid'
    end

    if #changes == 0 then return false, 'nothing' end

    if total > 0 then
        if exports.qbx_core:GetMoney(src, account) < total then return false, 'money' end
        if not exports.qbx_core:RemoveMoney(src, account, total, REASONS[store.type]) then return false, 'money' end
    end

    saveSkin(citizenid, newSkin)

    -- Tattoos go back to the client so illenium-appearance's own copy of them is updated too
    return true, { total = total, tattoos = #TATTOOS[store.type] > 0 and newSkin.tattoos or nil }
end)

lib.callback.register('city_clothing:saveOutfit', function(source, name)
    local src = source
    local citizenid = citizenOf(src)
    if not citizenid or not storeOf(src, 'clothing') then return false, 'far' end

    if type(name) ~= 'string' then return false, 'name' end
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    if #name < 1 or #name > 30 or not name:match(NAME_PATTERN) then return false, 'name' end

    local skin = loadSkin(citizenid)
    if not look.sexOf(skin) then return false, 'skin' end

    local exists = MySQL.scalar.await('SELECT id FROM player_outfits WHERE citizenid = ? AND outfitname = ? AND model = ?', {
        citizenid, name, skin.model,
    })

    if not exists then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM player_outfits WHERE citizenid = ? AND model = ?', {
            citizenid, skin.model,
        })
        if count >= Config.MaxOutfits then return false, 'full' end
    end

    -- What is saved is the paid look in the database, never what the page shows
    local components, props = look.outfitOf(skin)

    MySQL.insert.await([[
        INSERT INTO player_outfits (citizenid, outfitname, model, components, props) VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE components = VALUES(components), props = VALUES(props)
    ]], { citizenid, name, skin.model, json.encode(components), json.encode(props) })

    return true, outfits(citizenid, skin.model)
end)

lib.callback.register('city_clothing:wearOutfit', function(source, id)
    local src = source
    local citizenid = citizenOf(src)
    if not citizenid or not storeOf(src, 'clothing') then return false, 'far' end
    if not math.tointeger(id) then return false, 'id' end

    local skin = loadSkin(citizenid)
    if not look.sexOf(skin) then return false, 'skin' end

    local row = MySQL.single.await('SELECT components, props FROM player_outfits WHERE id = ? AND citizenid = ? AND model = ?', {
        id, citizenid, skin.model,
    })
    if not row then return false, 'id' end

    local newSkin = look.wear(skin, json.decode(row.components or '[]'), json.decode(row.props or '[]'))
    if not newSkin then
        warn(src, ('wear: bad outfit %d'):format(id))
        return false, 'invalid'
    end

    saveSkin(citizenid, newSkin)

    return true, newSkin
end)

lib.callback.register('city_clothing:deleteOutfit', function(source, id)
    local src = source
    local citizenid = citizenOf(src)
    if not citizenid or not storeOf(src, 'clothing') then return false, 'far' end
    if not math.tointeger(id) then return false, 'id' end

    local skin = loadSkin(citizenid)
    if not skin then return false, 'skin' end

    MySQL.update.await('DELETE FROM player_outfits WHERE id = ? AND citizenid = ?', { id, citizenid })

    return true, outfits(citizenid, skin.model)
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    lastBuy[source] = nil
end)
