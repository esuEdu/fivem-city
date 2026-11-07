-- Small checks and helpers shared by the server files. Pages only ever see a profile's numeric id, never a citizenid.
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
---@return table? player
function common.player(src)
    return exports.qbx_core:GetPlayer(src)
end

---The caller's profile row (nil until they made one)
---@param src integer
---@return table? profile { id, citizenid, name, gender, interest }
function common.profile(src)
    local player = common.player(src)
    if not player then return end

    common.wait()
    return MySQL.single.await('SELECT `id`, `citizenid`, `name`, `gender`, `interest` FROM `phone_dating_profiles` WHERE `citizenid` = ?', {
        player.PlayerData.citizenid,
    })
end

---A whole number from the page (JSON numbers can arrive as 5.0)
---@return integer?
function common.int(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

---Text from the page without control characters or < >; new lines kept when multiline
---@return string?
function common.text(value, max, multiline)
    if type(value) ~= 'string' then return end

    local clean = value:gsub('[\0-\9\11-\31<>]', '')
    if not multiline then clean = clean:gsub('\n', ' ') end

    return clean:match('^%s*(.-)%s*$'):sub(1, max)
end

---true when the same action came too soon after the last one
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

---One of the character's own photos (city_phone_photos), as an image
---@return string?
function common.photo(citizenid, id)
    id = common.int(id)
    if not id then return end

    local data = exports.city_phone_photos:Data(citizenid, id)
    if type(data) ~= 'string' or not data:find('^data:image/%a+;base64,[%w%+/=]+$') then return end

    return data
end

---The character's age from charinfo.birthdate (YYYY-MM-DD or DD-MM-YYYY); nil when it can't be read
---@param birthdate unknown
---@return integer?
function common.age(birthdate)
    if type(birthdate) ~= 'string' then return end

    local a, b, c = birthdate:match('^(%d+)[-/](%d+)[-/](%d+)')
    if not a then return end

    local year, month, day
    if #a == 4 then year, month, day = tonumber(a), tonumber(b), tonumber(c) else year, month, day = tonumber(c), tonumber(b), tonumber(a) end
    if year < 1900 then return end

    local now = os.date('*t')
    local age = now.year - year
    if now.month < month or (now.month == month and now.day < day) then age = age - 1 end

    return age >= 0 and age < 130 and age or nil
end

---A phone notification for a character, if they are online
---@param citizenid string
---@param text string
---@return integer? src the player's server id when online
function common.notify(citizenid, text)
    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if not player then return end

    exports.city_phone:Notify(player.PlayerData.source, { app = 'dating', title = 'Matchy', text = text })
    return player.PlayerData.source
end

AddEventHandler('playerDropped', function()
    last[source] = nil
end)

return common
