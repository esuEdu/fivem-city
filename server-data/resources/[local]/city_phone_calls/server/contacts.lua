-- The Phone app's data: contacts, recent calls and blocked numbers. Players only ever touch their own rows.
local calls = require 'server.calls'
local common = require 'server.common'
local store = require 'server.store'

lib.callback.register('city_phone_calls:data', function(source)
    local src = source
    local _, citizenid, number = common.player(src)
    if not citizenid then return end

    return {
        number = number,
        contacts = store.contacts(citizenid),
        recents = store.recents(citizenid),
        blocked = store.blocked(citizenid),
        call = calls.viewFor(src),
    }
end)

lib.callback.register('city_phone_calls:saveContact', function(source, data)
    local src = source
    local _, citizenid = common.player(src)
    if not citizenid or type(data) ~= 'table' or common.throttled(src, 'contact', 300) then return false end

    local name, number = common.name(data.name), common.number(data.number)
    if not name or not number then return false, 'invalid' end

    local favorite = data.favorite == true
    local id = math.tointeger(data.id)

    if id then return store.updateContact(citizenid, id, name, number, favorite) end
    if store.countContacts(citizenid) >= Config.MaxContacts then return false, 'full' end

    return store.addContact(citizenid, name, number, favorite) ~= nil
end)

lib.callback.register('city_phone_calls:deleteContact', function(source, id)
    local src = source
    local _, citizenid = common.player(src)
    id = math.tointeger(id)
    if not citizenid or not id or common.throttled(src, 'contact', 300) then return false end

    return store.deleteContact(citizenid, id)
end)

lib.callback.register('city_phone_calls:block', function(source, number, blocked)
    local src = source
    local _, citizenid = common.player(src)
    number = common.number(number)
    if not citizenid or not number or common.throttled(src, 'block', 300) then return false end

    return store.setBlocked(citizenid, number, blocked == true)
end)

lib.callback.register('city_phone_calls:clearRecents', function(source)
    local src = source
    local _, citizenid = common.player(src)
    if not citizenid or common.throttled(src, 'clear', 1000) then return false end

    store.clearRecents(citizenid)
    return true
end)

