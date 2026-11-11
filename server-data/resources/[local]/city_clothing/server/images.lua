-- Which pieces have a picture. index.json lists the photo tool's .webp files; .png files dropped into images/ by hand
-- (same name, e.g. m_c11_520.png) are found at start and win over the photo, for pieces the tool can't shoot well.
local images = {}

local RESOURCE = GetCurrentResourceName()
local INDEX_FILE = 'images/index.json'
local NAME = '^([mf]_[cpo]%d+_%d+)%.png$'

images.index = json.decode(LoadResourceFile(RESOURCE, INDEX_FILE) or '{}') or {}
images.custom = {}

local unsaved = 0

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
        local name = line:match(NAME)
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

function images.save()
    SaveResourceFile(RESOURCE, INDEX_FILE, json.encode(images.index), -1)
    unsaved = 0
end

---A photo was written: list it, saving the index every few pictures
function images.add(name)
    images.index[name] = true
    unsaved = unsaved + 1
    if unsaved >= 25 then images.save() end
end

return images
