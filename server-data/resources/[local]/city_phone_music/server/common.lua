-- Small checks and helpers shared by the server files
local common = {}

local ready = promise.new()
local last = {}

function common.setReady()
    ready:resolve()
end

function common.wait()
    if ready.state == 0 then Citizen.Await(ready) end
end

---@param src integer
---@return string? citizenid
function common.citizenid(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    common.wait()
    return player.PlayerData.citizenid
end

---A whole number from the page (JSON numbers can arrive as 5.0)
---@return integer?
function common.int(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

---One line of text without control characters or < >
---@return string?
function common.text(value, max)
    if type(value) ~= 'string' then return end
    return value:gsub('[%c<>]', ' '):match('^%s*(.-)%s*$'):sub(1, max)
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

---A YouTube video id from an id or any usual YouTube link
---@param value unknown
---@return string?
function common.youtubeId(value)
    if type(value) ~= 'string' or #value > Config.UrlLength then return end
    if value:find('^[%w_%-]+$') and #value == 11 then return value end

    local id = value:match('youtu%.be/([%w_%-]+)')
        or value:match('youtube%.com/watch%?.-v=([%w_%-]+)')
        or value:match('youtube%.com/shorts/([%w_%-]+)')
        or value:match('youtube%.com/embed/([%w_%-]+)')
        or value:match('music%.youtube%.com/watch%?.-v=([%w_%-]+)')

    if id and #id == 11 then return id end
end

---A direct audio link: https, a known extension, nothing that could break out of an attribute
---@param value unknown
---@return string?
function common.audioUrl(value)
    if type(value) ~= 'string' or #value > Config.UrlLength or not value:find('^https://[%w%.%-]+/') then return end
    if value:find('[%s"\'<>\\]') then return end

    local extension = value:match('%.(%w+)$') or value:match('%.(%w+)%?')
    if not extension then return end

    extension = extension:lower()
    for _, allowed in ipairs(Config.AudioExtensions) do
        if allowed == extension then return value end
    end
end

AddEventHandler('playerDropped', function()
    last[source] = nil
end)

return common
