-- Finding songs: searching YouTube by title (YouTube Data API, key in the server-only convar youtube_api_key) and
-- reading a pasted link (YouTube's oEmbed gives the title without a key). Requests go out from the server only.
local common = require 'server.common'

local SEARCH_URL = 'https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&videoEmbeddable=true&maxResults=%d&q=%s&key=%s'
local OEMBED_URL = 'https://www.youtube.com/oembed?format=json&url=https%%3A%%2F%%2Fwww.youtube.com%%2Fwatch%%3Fv%%3D%s'
local TIMEOUT_MS = 8000

---@type table<string, { at: integer, results: table[] }>
local cache = {}

local ENTITIES = { amp = '&', quot = '"', lt = '', gt = '', apos = "'" }

---Titles from the API come HTML-escaped (&amp; &#39;)
local function unescape(text)
    text = text:gsub('&#(%d+);', function(code)
        code = tonumber(code)
        return code and code < 128 and string.char(code) or ''
    end)
    return (text:gsub('&(%a+);', function(name) return ENTITIES[name] or '' end))
end

local function urlencode(text)
    return (text:gsub('[^%w%-_%.~ ]', function(char) return ('%%%02X'):format(char:byte()) end):gsub(' ', '+'))
end

---GET a URL and decode its JSON; nil on any failure or after TIMEOUT_MS
local function getJson(url)
    local result = promise.new()

    PerformHttpRequest(url, function(status, body)
        if status ~= 200 or type(body) ~= 'string' then return result:resolve(nil) end

        local ok, data = pcall(json.decode, body)
        result:resolve(ok and data or nil)
    end, 'GET', '', { ['Accept'] = 'application/json' })

    SetTimeout(TIMEOUT_MS, function()
        if result.state == 0 then result:resolve(nil) end
    end)

    return Citizen.Await(result)
end

lib.callback.register('city_phone_music:canSearch', function()
    return GetConvar('youtube_api_key', '') ~= ''
end)

lib.callback.register('city_phone_music:search', function(source, query)
    local src = source
    if not common.citizenid(src) then return false, 'invalid' end

    local key = GetConvar('youtube_api_key', '')
    if key == '' then return false, 'no_key' end

    query = common.text(query, 80)
    if not query or #query < 2 then return false, 'invalid' end

    local cacheKey = query:lower()
    local cached = cache[cacheKey]
    if cached and os.time() - cached.at < Config.SearchCacheMinutes * 60 then return cached.results end

    if common.throttled(src, 'search', Config.SearchCooldown * 1000) then return false, 'slow' end

    local data = getJson(SEARCH_URL:format(Config.SearchResults, urlencode(query), key))
    if type(data) ~= 'table' or type(data.items) ~= 'table' then
        lib.print.warn('city_phone_music: YouTube search failed (check youtube_api_key and its quota)')
        return false, 'failed'
    end

    local results = {}

    for _, item in ipairs(data.items) do
        local id = type(item.id) == 'table' and common.youtubeId(item.id.videoId)
        local snippet = type(item.snippet) == 'table' and item.snippet

        if id and snippet then
            local thumbnails = type(snippet.thumbnails) == 'table' and snippet.thumbnails or {}
            local thumb = (thumbnails.medium or thumbnails.default or {}).url

            results[#results + 1] = {
                kind = 'youtube',
                ref = id,
                title = unescape(tostring(snippet.title or '')):sub(1, Config.TitleLength),
                artist = unescape(tostring(snippet.channelTitle or '')):sub(1, Config.TitleLength),
                thumb = type(thumb) == 'string' and thumb:find('^https://i%.ytimg%.com/') and thumb or nil,
            }
        end
    end

    cache[cacheKey] = { at = os.time(), results = results }
    return results
end)

-- A pasted link: YouTube (title and channel from oEmbed) or a direct audio file (title from the file name)
lib.callback.register('city_phone_music:lookup', function(source, link)
    local src = source
    if not common.citizenid(src) or common.throttled(src, 'lookup', 1000) then return false, 'invalid' end

    local id = common.youtubeId(link)

    if id then
        local data = getJson(OEMBED_URL:format(id))
        if type(data) ~= 'table' or type(data.title) ~= 'string' then return false, 'unavailable' end

        return {
            kind = 'youtube',
            ref = id,
            title = data.title:sub(1, Config.TitleLength),
            artist = tostring(data.author_name or ''):sub(1, Config.TitleLength),
            thumb = ('https://i.ytimg.com/vi/%s/mqdefault.jpg'):format(id),
        }
    end

    local url = common.audioUrl(link)
    if not url then return false, 'link' end

    local file = url:match('/([^/%?]+)%.%w+%??[^/]*$') or 'Audio'

    return { kind = 'url', ref = url, title = file:gsub('[%%_%-]+', ' '):sub(1, Config.TitleLength), artist = '' }
end)

-- Old searches are forgotten
CreateThread(function()
    while true do
        Wait(600000)

        local now = os.time()
        for key, entry in pairs(cache) do
            if now - entry.at > Config.SearchCacheMinutes * 60 then cache[key] = nil end
        end
    end
end)
