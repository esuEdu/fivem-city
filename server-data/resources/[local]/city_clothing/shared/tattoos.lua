-- The tattoo catalog, read from illenium-appearance's own list (shared/tattoos.lua) so there is no second copy to keep
-- in step. Each entry: name, label, hashMale, hashFemale, zone, collection; an empty hash means not for that sex.
local tattoos = {}

local function readCatalog()
    local source = LoadResourceFile('illenium-appearance', 'shared/tattoos.lua')
    if not source then return {} end

    local env = { Config = {} }
    local chunk = load(source, '@illenium-appearance/shared/tattoos.lua', 't', env)
    if not chunk or not pcall(chunk) then return {} end

    return env.Config.Tattoos or {}
end

local byZone = readCatalog()
local byName = {}

for zone, list in pairs(byZone) do
    for i = 1, #list do
        local entry = list[i]
        entry.zone = zone
        byName[entry.name] = entry
    end
end

---A tattoo by name, or nil
function tattoos.get(name)
    return byName[name]
end

---The game hash of a tattoo for a sex ('m' / 'f'), or nil when it doesn't exist for that sex
function tattoos.hashFor(entry, sex)
    local hash = sex == 'f' and entry.hashFemale or entry.hashMale
    if type(hash) ~= 'string' or hash == '' then return nil end
    return hash
end

---The tattoos of a zone that a sex can wear, in the catalog's order
function tattoos.list(zone, sex)
    local out = {}
    for _, entry in ipairs(byZone[zone] or {}) do
        if tattoos.hashFor(entry, sex) then out[#out + 1] = entry end
    end
    return out
end

return tattoos
