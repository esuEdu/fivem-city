-- Small checks and helpers shared by the server files
local common = {}

local ready = promise.new()
local last = {}

function common.setReady()
    ready:resolve()
end

-- Queries wait until the tables exist
function common.wait()
    if ready.state == 0 then Citizen.Await(ready) end
end

---@param src integer
---@return string? citizenid
function common.citizenid(src)
    local player = exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData.citizenid or nil
end

---The caller's account (nil until they made one)
---@param src integer
---@return table? account { citizenid, username, name }
function common.account(src)
    local citizenid = common.citizenid(src)
    if not citizenid then return end

    common.wait()
    return MySQL.single.await('SELECT `citizenid`, `username`, `name` FROM `phone_social_accounts` WHERE `citizenid` = ?', { citizenid })
end

---A whole number from the page (JSON numbers can arrive as 5.0)
---@return integer?
function common.int(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

---Text from the page without control characters or < >; new lines kept when multiline
---@param value unknown
---@param max integer
---@param multiline boolean?
---@return string?
function common.text(value, max, multiline)
    if type(value) ~= 'string' then return end

    local clean = value:gsub('[\0-\9\11-\31<>]', '')
    if not multiline then clean = clean:gsub('\n', ' ') end
    clean = clean:match('^%s*(.-)%s*$')

    return clean:sub(1, max)
end

---true when the same action came too soon after the last one
---@param src integer
---@param key string
---@param ms integer
function common.throttled(src, key, ms)
    local now = GetGameTimer()
    local byKey = last[src] or {}

    last[src] = byKey
    if byKey[key] and now - byKey[key] < ms then return true end

    byKey[key] = now
    return false
end

function common.hasPhone(src)
    return exports.city_inventory:GetItemCount(src, Config.Item) > 0
end

function common.isStaff(src)
    return IsPlayerAceAllowed(tostring(src), Config.StaffAce)
end

---One of the character's own photos (city_phone_photos), as an image
---@return string?
function common.photo(citizenid, id)
    id = common.int(id)
    if not id then return end

    local data = exports.city_phone_photos:Data(citizenid, id)
    if type(data) ~= 'string' or not data:find('^data:image/%a+;base64,[%w%+/=]+$') then return end

    return data
end

---A phone notification for a character, if they are online and it isn't themselves
---@param citizenid string who gets it
---@param from string citizenid of who did it
---@param text string
function common.notify(citizenid, from, text)
    if citizenid == from then return end

    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if not player then return end

    exports.city_phone:Notify(player.PlayerData.source, { app = 'social', title = 'InstaPic', text = text })
end

---@param src integer
---@param action string
---@param ownerCitizenid string
---@param details string
function common.staffLog(src, action, ownerCitizenid, details)
    if GetResourceState('city_staff') ~= 'started' then return end
    exports.city_staff:Log(src, action, { citizenid = ownerCitizenid }, details)
end

AddEventHandler('playerDropped', function()
    last[source] = nil
end)

return common
