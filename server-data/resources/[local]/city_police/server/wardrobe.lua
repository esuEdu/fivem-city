-- The station wardrobe: put on a uniform (the officer's own clothes are kept in city_police_wardrobe until they change
-- back, even after logging out), change back (and clock out), and the chief's uniforms (city_police_uniforms).

local police = require 'server.police'
local outfit = require 'server.outfit'
local db = require 'server.db'

local RANGE = Config.Ranges.place + 1.0
local LABEL_MAX = 40

---@param src integer
---@return boolean
local function atWardrobe(src)
    for _, station in ipairs(Config.Stations) do
        if station.wardrobe and police.near(src, station.wardrobe, RANGE) then return true end
    end

    return false
end

---Config uniforms and the ones made in game, as the page lists them.
---@return table[]
local function allUniforms()
    local list = {}

    for _, uniform in ipairs(Config.Uniforms) do
        list[#list + 1] = { id = uniform.id, label = uniform.label, sex = uniform.sex, components = uniform.components, props = uniform.props, fixed = true }
    end

    for _, row in ipairs(MySQL.query.await('SELECT id, label, sex, components, props, created_by FROM city_police_uniforms ORDER BY label') or {}) do
        list[#list + 1] = { id = row.id, label = row.label, sex = row.sex, components = db.list(row.components), props = db.list(row.props), by = row.created_by }
    end

    return list
end

---@param id unknown config id (string) or database id (integer)
---@return table?
local function findUniform(id)
    for _, uniform in ipairs(allUniforms()) do
        if uniform.id == id then return uniform end
    end
end

---@param citizenid string
---@return boolean
local function hasBackup(citizenid)
    return MySQL.scalar.await('SELECT 1 FROM city_police_wardrobe WHERE citizenid = ?', { citizenid }) ~= nil
end

---Keeps the officer's own clothes, once: switching between uniforms doesn't overwrite them.
---@param citizenid string
---@param current table { components, props } from the client
---@return boolean
local function keepOwnClothes(citizenid, current)
    if hasBackup(citizenid) then return true end

    local components, props = outfit.check(type(current) == 'table' and current.components, type(current) == 'table' and current.props)
    if not components then return false end

    MySQL.insert.await('INSERT INTO city_police_wardrobe (citizenid, components, props, saved) VALUES (?, ?, ?, ?)', {
        citizenid, json.encode(components), json.encode(props), os.time(),
    })

    return true
end

lib.callback.register('city_police:wardrobe:list', function(source)
    local src = source
    if not police.isCop(src) or not atWardrobe(src) then return end

    return {
        uniforms = allUniforms(),
        canManage = police.can(src, 'uniforms'),
        wearing = hasBackup(police.citizenid(src)),
        onDuty = police.onDuty(src),
    }
end)

lib.callback.register('city_police:wardrobe:wear', function(source, id, current)
    local src = source
    if not police.isCop(src) or not atWardrobe(src) then return false, 'too_far' end

    local uniform = findUniform(id)
    if not uniform then return false, 'not_found' end
    if not keepOwnClothes(police.citizenid(src), current) then return false, 'invalid' end

    return true, { components = uniform.components, props = uniform.props }
end)

-- Back to their own clothes; offDuty also clocks them out
lib.callback.register('city_police:wardrobe:changeBack', function(source, offDuty)
    local src = source
    if not police.isCop(src) or not atWardrobe(src) then return false, 'too_far' end

    local citizenid = police.citizenid(src)
    local row = MySQL.single.await('SELECT components, props FROM city_police_wardrobe WHERE citizenid = ?', { citizenid })
    if offDuty == true and police.onDuty(src) then exports.qbx_core:SetJobDuty(src, false) end
    if not row then return true, nil end

    MySQL.update.await('DELETE FROM city_police_wardrobe WHERE citizenid = ?', { citizenid })

    return true, { components = db.list(row.components), props = db.list(row.props) }
end)

-- The chief is about to dress up a new uniform: keep their clothes first, as when putting one on
lib.callback.register('city_police:wardrobe:startDesign', function(source, current)
    local src = source
    if not police.can(src, 'uniforms') or not atWardrobe(src) then return false, 'no_permission' end

    return keepOwnClothes(police.citizenid(src), current), 'invalid'
end)

lib.callback.register('city_police:wardrobe:create', function(source, data)
    local src = source
    if not police.can(src, 'uniforms') then
        police.warn(src, 'tried to create a uniform without the grade')
        return false, 'no_permission'
    end
    if not atWardrobe(src) or type(data) ~= 'table' then return false, 'too_far' end

    local label = police.clean(data.label, LABEL_MAX)
    local sex = outfit.sex(data.sex)
    local components, props = outfit.check(data.components, data.props)
    if label == '' or not sex or not components then return false, 'invalid' end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM city_police_uniforms') or 0
    if count >= Config.MaxUniforms then return false, 'too_many' end

    local id = MySQL.insert.await('INSERT INTO city_police_uniforms (label, sex, components, props, created_by, created) VALUES (?, ?, ?, ?, ?, ?)', {
        label, sex, json.encode(components), json.encode(props), police.name(src), os.time(),
    })

    return id ~= nil, id
end)

lib.callback.register('city_police:wardrobe:delete', function(source, id)
    local src = source
    if not police.can(src, 'uniforms') then return false, 'no_permission' end

    id = math.tointeger(id)
    if not id or id < 1 then return false, 'invalid' end

    return (MySQL.update.await('DELETE FROM city_police_uniforms WHERE id = ?', { id }) or 0) > 0, 'not_found'
end)
