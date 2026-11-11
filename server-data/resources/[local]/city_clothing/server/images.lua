-- The pictures of the pieces. The photo tool's pictures are kept in one pack per sex and tab
-- (images/pack_<sex>_<key>.json: { ["<style>"] = "data:image/webp;base64,..." }): thousands of loose files made the
-- resource too big a package for the server to build when a player joins. Packs are loaded only when used.
-- .png files dropped into images/ by hand (e.g. m_c11_520.png, or m_ttorso_TAT_AR_000.png for a tattoo) are found at
-- start and win over the photo.
local images = {}

local RESOURCE = GetCurrentResourceName()
local CUSTOM_NAME = '^([mf]_%w+_[%w_]+)%.png$'
local SAVE_EVERY = 25

images.custom = {}

---@type table<string, { data: table<string, string>, dirty: integer }>
local packs = {}

local function packFile(sex, key)
    return ('images/pack_%s_%s.json'):format(sex, key)
end

local function pack(sex, key)
    local name = sex .. '_' .. key
    if packs[name] then return packs[name] end

    local ok, data = pcall(json.decode, LoadResourceFile(RESOURCE, packFile(sex, key)) or '{}')
    packs[name] = { sex = sex, key = key, data = ok and type(data) == 'table' and data or {}, dirty = 0 }

    return packs[name]
end

local function save(entry)
    SaveResourceFile(RESOURCE, packFile(entry.sex, entry.key), json.encode(entry.data), -1)
    entry.dirty = 0
end

---The styles of a tab that already have a picture, as a set
function images.have(sex, key)
    local set = {}
    for style in pairs(pack(sex, key).data) do set[tonumber(style) or style] = true end
    return set
end

---Keeps a picture (a data URI from screencapture), writing the pack every few pictures
function images.add(sex, key, style, dataUri)
    local entry = pack(sex, key)
    entry.data[tostring(style)] = dataUri
    entry.dirty = entry.dirty + 1
    if entry.dirty >= SAVE_EVERY then save(entry) end
end

function images.saveAll()
    for _, entry in pairs(packs) do
        if entry.dirty > 0 then save(entry) end
    end
end

local function listCommand(dir)
    if package.config:sub(1, 1) == '\\' then
        return ('dir /b "%s\\*.png" 2>nul'):format(dir:gsub('/', '\\'))
    end

    return ("ls -1 '%s' 2>/dev/null"):format(dir:gsub("'", "'\\''"))
end

local function scanCustom()
    local root = GetResourcePath(RESOURCE)
    if not root or not io or not io.popen then return end

    local ok, output = pcall(function()
        local handle = io.popen(listCommand(root .. '/images'))
        if not handle then return end

        local text = handle:read('a')
        handle:close()
        return text
    end)

    if not ok or not output then return end

    local count = 0
    for line in output:gmatch('[^\r\n]+') do
        local name = line:match(CUSTOM_NAME)
        if name then
            images.custom[name] = true
            count = count + 1
        end
    end

    if count > 0 then lib.print.info(('city_clothing: %d hand-made pictures in images/'):format(count)) end
end

scanCustom()

---The hand-made pictures of one sex, for the shop page
function images.customFor(sex)
    local list = {}
    local prefix = sex .. '_'
    for name in pairs(images.custom) do
        if name:sub(1, 2) == prefix then list[name] = true end
    end
    return list
end

return images
