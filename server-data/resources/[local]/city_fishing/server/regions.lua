-- Which water a bobber is in, from rough polygons (x, y). Inland waters are tested first; salt water inside the coast
-- outline is the ocean and everything outside it is the deep sea. The client only says "this is water"; the region
-- comes from the position here. Polygons were drawn from the map without the game open: check them in game.
local regions = {}

local INLAND = {
    {
        id = 'alamo',
        polygon = { { 290, 3880 }, { 700, 3650 }, { 1500, 3600 }, { 2250, 3780 }, { 2500, 4100 }, { 2300, 4550 }, { 1700, 4650 }, { 900, 4450 }, { 450, 4250 } },
    },
    {
        id = 'lake', -- Land Act Reservoir
        polygon = { { 1550, -100 }, { 2350, -100 }, { 2350, 800 }, { 1550, 800 } },
    },
    {
        id = 'lake', -- Mirror Park lake
        polygon = { { 1020, -720 }, { 1200, -720 }, { 1200, -560 }, { 1020, -560 } },
    },
    {
        id = 'lake', -- Vinewood Lake (Tongva Hills reservoir)
        polygon = { { -200, 700 }, { 250, 700 }, { 250, 1000 }, { -200, 1000 } },
    },
    {
        id = 'river', -- Zancudo River
        polygon = { { -2950, 2350 }, { -1300, 2350 }, { -1300, 3300 }, { -2950, 3300 } },
    },
    {
        id = 'river', -- Cassidy Creek and Raton Canyon
        polygon = { { -1800, 4200 }, { 100, 4200 }, { 100, 4650 }, { -1800, 4650 } },
    },
    {
        id = 'canal', -- LS River canal
        polygon = { { 490, -2700 }, { 1050, -2700 }, { 1150, -150 }, { 850, -150 } },
    },
}

-- The island plus a few hundred metres of sea; outside it is the deep sea
local COAST = {
    { -3800, -3500 }, { -1500, -4000 }, { 1800, -3900 }, { 3800, -1500 }, { 4200, 3000 }, { 3900, 6500 },
    { 2000, 7700 }, { -500, 7600 }, { -2500, 6000 }, { -3900, 2000 },
}

-- The highest shore distance each region can have (narrow rivers and the canal never get far from the bank)
local MAX_SHORE = { ocean = 5, deep = 5, alamo = 5, lake = 5, river = 3, canal = 2 }

-- Legendary spots: a circle each (x, y, radius)
local SPOTS = {
    ghost_sturgeon = { 1320.0, 4380.0, 60.0 },
    golden_marlin = { -1200.0, 7900.0, 300.0 },
    king_salmon = { -2650.0, 2600.0, 70.0 },
    chiliad_rainbow = { -560.0, 4410.0, 50.0 },
    canal_leviathan = { 680.0, -1060.0, 60.0 },
}

---Ray casting point-in-polygon.
---@param x number
---@param y number
---@param polygon number[][]
---@return boolean
function regions.inside(x, y, polygon)
    local inside = false
    local j = #polygon

    for i = 1, #polygon do
        local xi, yi = polygon[i][1], polygon[i][2]
        local xj, yj = polygon[j][1], polygon[j][2]

        if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then
            inside = not inside
        end

        j = i
    end

    return inside
end

---@param x number
---@param y number
---@return string
function regions.at(x, y)
    for _, region in ipairs(INLAND) do
        if regions.inside(x, y, region.polygon) then return region.id end
    end

    return regions.inside(x, y, COAST) and 'ocean' or 'deep'
end

---The shore distance the client measured, capped by the region (the deep sea is always the farthest).
---@param region string
---@param measured unknown
---@return integer
function regions.shore(region, measured)
    if region == 'deep' then return 5 end

    measured = math.tointeger(measured) or 0

    return math.max(0, math.min(measured, MAX_SHORE[region] or 5))
end

---Whether a legendary's spot contains this point.
---@param id string
---@param x number
---@param y number
---@return boolean
function regions.atSpot(id, x, y)
    local spot = SPOTS[id]
    if not spot then return false end

    local dx, dy = x - spot[1], y - spot[2]

    return dx * dx + dy * dy <= spot[3] * spot[3]
end

---Fresh or salt water, for crab pots.
---@param region string
---@return string
function regions.water(region)
    return (region == 'ocean' or region == 'deep' or region == 'alamo') and 'salt' or 'fresh'
end

return regions
