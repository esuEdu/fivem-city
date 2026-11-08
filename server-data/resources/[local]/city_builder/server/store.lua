-- Placed props, groups and hidden map props: loaded once at start, kept in memory, written through to the database.
local store = {
    props = {}, ---@type table<integer, table>
    groups = {}, ---@type table<integer, table>
    hides = {}, ---@type table<integer, table>
    count = 0,
}

local function toProp(row)
    return {
        id = row.id,
        model = row.model,
        x = row.x, y = row.y, z = row.z,
        rx = row.rx, ry = row.ry, rz = row.rz,
        collision = row.collision == 1 or row.collision == true,
        group = row.group_id,
    }
end

function store.load()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_builder_groups` (
            `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(40) NOT NULL,
            `enabled` TINYINT(1) NOT NULL DEFAULT 1,
            `created_by` VARCHAR(50) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_builder_props` (
            `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `model` VARCHAR(64) NOT NULL,
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `rx` FLOAT NOT NULL DEFAULT 0,
            `ry` FLOAT NOT NULL DEFAULT 0,
            `rz` FLOAT NOT NULL DEFAULT 0,
            `collision` TINYINT(1) NOT NULL DEFAULT 1,
            `group_id` INT NULL,
            `created_by` VARCHAR(50) NULL,
            `updated_by` VARCHAR(50) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX (`group_id`)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_builder_hides` (
            `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `model` INT NOT NULL,
            `label` VARCHAR(64) NOT NULL,
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `radius` FLOAT NOT NULL,
            `created_by` VARCHAR(50) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    for _, row in ipairs(MySQL.query.await('SELECT `id`, `name`, `enabled` FROM `city_builder_groups`') or {}) do
        store.groups[row.id] = { id = row.id, name = row.name, enabled = row.enabled == 1 or row.enabled == true }
    end

    local props = MySQL.query.await('SELECT `id`, `model`, `x`, `y`, `z`, `rx`, `ry`, `rz`, `collision`, `group_id` FROM `city_builder_props`') or {}

    for _, row in ipairs(props) do
        store.props[row.id] = toProp(row)
        store.count = store.count + 1
    end

    for _, row in ipairs(MySQL.query.await('SELECT `id`, `model`, `label`, `x`, `y`, `z`, `radius` FROM `city_builder_hides`') or {}) do
        store.hides[row.id] = row
    end
end

---@param prop table checked by validate.prop
---@param by string citizenid
---@return table? prop with its id
function store.create(prop, by)
    local id = MySQL.insert.await([[
        INSERT INTO `city_builder_props` (`model`, `x`, `y`, `z`, `rx`, `ry`, `rz`, `collision`, `group_id`, `created_by`, `updated_by`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { prop.model, prop.x, prop.y, prop.z, prop.rx, prop.ry, prop.rz, prop.collision and 1 or 0, prop.group, by, by })
    if not id then return end

    local saved = {
        id = id, model = prop.model, x = prop.x, y = prop.y, z = prop.z,
        rx = prop.rx, ry = prop.ry, rz = prop.rz, collision = prop.collision, group = prop.group,
    }

    store.props[id] = saved
    store.count = store.count + 1

    return saved
end

---@return table? prop
function store.update(id, prop, by)
    local current = store.props[id]
    if not current then return end

    local changed = MySQL.update.await([[
        UPDATE `city_builder_props` SET `model` = ?, `x` = ?, `y` = ?, `z` = ?, `rx` = ?, `ry` = ?, `rz` = ?,
            `collision` = ?, `group_id` = ?, `updated_by` = ? WHERE `id` = ?
    ]], { prop.model, prop.x, prop.y, prop.z, prop.rx, prop.ry, prop.rz, prop.collision and 1 or 0, prop.group, by, id })
    if not changed or changed < 1 then return end

    current.model, current.x, current.y, current.z = prop.model, prop.x, prop.y, prop.z
    current.rx, current.ry, current.rz = prop.rx, prop.ry, prop.rz
    current.collision, current.group = prop.collision, prop.group

    return current
end

---@return table? prop as it was
function store.delete(id)
    local current = store.props[id]
    if not current then return end

    MySQL.query.await('DELETE FROM `city_builder_props` WHERE `id` = ?', { id })
    store.props[id] = nil
    store.count = store.count - 1

    return current
end

---@return table? group
function store.createGroup(name, by)
    local id = MySQL.insert.await('INSERT INTO `city_builder_groups` (`name`, `created_by`) VALUES (?, ?)', { name, by })
    if not id then return end

    store.groups[id] = { id = id, name = name, enabled = true }

    return store.groups[id]
end

---@return table? group
function store.updateGroup(id, name, enabled)
    local group = store.groups[id]
    if not group then return end

    MySQL.update.await('UPDATE `city_builder_groups` SET `name` = ?, `enabled` = ? WHERE `id` = ?', { name, enabled and 1 or 0, id })
    group.name, group.enabled = name, enabled

    return group
end

---Deletes a group and every prop in it.
---@return integer[]? ids of the deleted props
function store.deleteGroup(id)
    if not store.groups[id] then return end

    local ids = {}

    for propId, prop in pairs(store.props) do
        if prop.group == id then ids[#ids + 1] = propId end
    end

    MySQL.transaction.await({
        { query = 'DELETE FROM `city_builder_props` WHERE `group_id` = ?', values = { id } },
        { query = 'DELETE FROM `city_builder_groups` WHERE `id` = ?', values = { id } },
    })

    for _, propId in ipairs(ids) do
        store.props[propId] = nil
        store.count = store.count - 1
    end

    store.groups[id] = nil

    return ids
end

---Deletes every prop that has no group.
---@return integer[] ids of the deleted props
function store.deleteUngrouped()
    local ids = {}

    for propId, prop in pairs(store.props) do
        if not prop.group then ids[#ids + 1] = propId end
    end

    if #ids == 0 then return ids end

    MySQL.query.await('DELETE FROM `city_builder_props` WHERE `group_id` IS NULL')

    for _, propId in ipairs(ids) do
        store.props[propId] = nil
        store.count = store.count - 1
    end

    return ids
end

---The props of a group (0 = the ones without a group), sorted by id.
---@return table[]
function store.groupProps(id)
    local list = {}

    for _, prop in pairs(store.props) do
        if (id == 0 and not prop.group) or (id ~= 0 and prop.group == id) then list[#list + 1] = prop end
    end

    table.sort(list, function(a, b) return a.id < b.id end)

    return list
end

---Moves every prop of a group by an offset.
---@return table[]? props after the move
function store.moveGroup(id, dx, dy, dz, by)
    if not store.groups[id] then return end

    MySQL.update.await('UPDATE `city_builder_props` SET `x` = `x` + ?, `y` = `y` + ?, `z` = `z` + ?, `updated_by` = ? WHERE `group_id` = ?',
        { dx, dy, dz, by, id })

    local moved = {}

    for _, prop in pairs(store.props) do
        if prop.group == id then
            prop.x, prop.y, prop.z = prop.x + dx, prop.y + dy, prop.z + dz
            moved[#moved + 1] = prop
        end
    end

    return moved
end

---@return table? hide
function store.createHide(hide, radius, by)
    local id = MySQL.insert.await([[
        INSERT INTO `city_builder_hides` (`model`, `label`, `x`, `y`, `z`, `radius`, `created_by`) VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { hide.model, hide.label, hide.x, hide.y, hide.z, radius, by })
    if not id then return end

    store.hides[id] = { id = id, model = hide.model, label = hide.label, x = hide.x, y = hide.y, z = hide.z, radius = radius }

    return store.hides[id]
end

---@return table? hide as it was
function store.deleteHide(id)
    local hide = store.hides[id]
    if not hide then return end

    MySQL.query.await('DELETE FROM `city_builder_hides` WHERE `id` = ?', { id })
    store.hides[id] = nil

    return hide
end

---Everything a client needs to draw the world, as arrays.
function store.snapshot()
    local props, groups, hides = {}, {}, {}

    for _, prop in pairs(store.props) do props[#props + 1] = prop end
    for _, group in pairs(store.groups) do groups[#groups + 1] = group end
    for _, hide in pairs(store.hides) do hides[#hides + 1] = hide end

    return { props = props, groups = groups, hides = hides }
end

return store
