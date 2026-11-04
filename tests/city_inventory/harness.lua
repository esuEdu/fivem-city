-- Plain-Lua stand-ins for what city_inventory gets from FiveM and ox_lib, so its server logic can run outside the game.
-- Each test file starts with dofile('harness.lua') and is run by scripts/check.sh as: luajit <test>.lua <resource dir>
-- Tests that need natives (GetEntityCoords, exports, ...) stub them themselves.

local root = arg[1]

-- Lua 5.4 functions the resource uses that LuaJIT doesn't have
loadstring = loadstring or load

math.type = function(value)
    if type(value) ~= 'number' then return nil end
    return (value == math.floor(value) and value ~= math.huge) and 'integer' or 'float'
end

math.tointeger = function(value)
    if type(value) == 'number' and value == math.floor(value) then return value end
end

local function matches(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end

    for key, value in pairs(a) do
        if b[key] == nil or not matches(value, b[key]) then return false end
    end

    for key in pairs(b) do
        if a[key] == nil then return false end
    end

    return true
end

local function deepclone(value)
    if type(value) ~= 'table' then return value end

    local copy = {}
    for key, inner in pairs(value) do copy[key] = deepclone(inner) end

    return copy
end

local serials = 0

vec3 = function(x, y, z) return { x = x, y = y, z = z } end

Config = { MaxClip = 100, ReserveMagazines = 8, MaxGunAmmo = 250, Categories = {} }

for _, name in ipairs({ 'weapon', 'ammo', 'food', 'drink', 'medical', 'drug', 'tool', 'electronics', 'valuable', 'material', 'document', 'misc' }) do
    Config.Categories[#Config.Categories + 1] = { name = name }
end

lib = {
    table = { matches = matches, deepclone = deepclone },
    string = {
        random = function()
            serials = serials + 1
            return 'SER' .. serials
        end,
    },
    print = { warn = print, error = print, info = print },
}

-- ox_lib's require: modules by dotted path from the resource folder, with backtick hashes turned into strings
local modules = {}

function require(name)
    if modules[name] ~= nil then return modules[name] end

    local source = assert(io.open(root .. '/' .. name:gsub('%.', '/') .. '.lua')):read('*a')
    source = source:gsub('`([^`]+)`', '"%1"')

    modules[name] = assert(loadstring(source, name))()

    return modules[name]
end
