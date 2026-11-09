-- Points placed by staff in game (/miningpoints): where veins, gravel and the passage blocker can be. Saved in
-- city_mining_points; a region's area (centre and radius) is worked out from its points.
local points = {}

local KINDS = { vein = true, gravel = true, passage = true }

---@type table<integer, table> id -> { id, region, kind, coords: vector4 }
points.byId = {}
---@type table<string, table[]> region -> points
points.byRegion = {}
---@type table<string, { center: vector3, radius: number }>
points.areas = {}

local regionById = {}
for _, region in ipairs(Config.Regions) do regionById[region.id] = region end

points.regions = regionById

local function rebuild()
    points.byRegion = {}

    for _, point in pairs(points.byId) do
        local list = points.byRegion[point.region] or {}
        list[#list + 1] = point
        points.byRegion[point.region] = list
    end

    points.areas = {}

    for region, list in pairs(points.byRegion) do
        local sum = vec3(0, 0, 0)
        for _, point in ipairs(list) do sum = sum + point.coords.xyz end

        local center = sum / #list
        local radius = 0
        for _, point in ipairs(list) do radius = math.max(radius, #(point.coords.xyz - center)) end

        points.areas[region] = { center = center, radius = radius + 40.0 }
    end
end

function points.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `city_mining_points` (
            `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `region` VARCHAR(30) NOT NULL,
            `kind` VARCHAR(10) NOT NULL,
            `x` FLOAT NOT NULL,
            `y` FLOAT NOT NULL,
            `z` FLOAT NOT NULL,
            `h` FLOAT NOT NULL DEFAULT 0,
            `created_by` VARCHAR(50) NULL
        )
    ]])

    for _, row in ipairs(MySQL.query.await('SELECT `id`, `region`, `kind`, `x`, `y`, `z`, `h` FROM `city_mining_points`') or {}) do
        if regionById[row.region] and KINDS[row.kind] then
            points.byId[row.id] = { id = row.id, region = row.region, kind = row.kind, coords = vec4(row.x, row.y, row.z, row.h) }
        end
    end

    rebuild()
end

---@param region string
---@param kind string
---@param coords vector4
---@param citizenid string
---@return table? point
function points.add(region, kind, coords, citizenid)
    if not regionById[region] or not KINDS[kind] then return end

    local id = MySQL.insert.await('INSERT INTO `city_mining_points` (`region`, `kind`, `x`, `y`, `z`, `h`, `created_by`) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        region, kind, coords.x, coords.y, coords.z, coords.w, citizenid,
    })
    if not id then return end

    local point = { id = id, region = region, kind = kind, coords = coords }
    points.byId[id] = point
    rebuild()

    return point
end

---@param id integer
---@return table? removed
function points.remove(id)
    local point = points.byId[id]
    if not point then return end

    MySQL.prepare.await('DELETE FROM `city_mining_points` WHERE `id` = ?', { id })
    points.byId[id] = nil
    rebuild()

    return point
end

---Points of one kind in a region.
---@param region string
---@param kind string
---@return table[]
function points.of(region, kind)
    local list = {}

    for _, point in ipairs(points.byRegion[region] or {}) do
        if point.kind == kind then list[#list + 1] = point end
    end

    return list
end

---The region whose area holds these coordinates.
---@param coords vector3
---@return table? region
function points.regionAt(coords)
    for id, area in pairs(points.areas) do
        if #(coords - area.center) <= area.radius then return regionById[id] end
    end
end

---What every client needs to draw blips and staff markers: areas only.
---@return table
function points.publicAreas()
    local list = {}

    for id, area in pairs(points.areas) do
        local region = regionById[id]
        list[#list + 1] = { id = id, label = region.label, kind = region.kind, blip = region.blip, center = area.center, radius = area.radius }
    end

    return list
end

return points
