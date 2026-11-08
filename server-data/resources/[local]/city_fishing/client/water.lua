-- Is there open water at a point, and how far is the bobber from the shore? Rivers aren't water quads, so the probe
-- goes against all water; a world hit above the water surface (land, a pier, a rock) means it isn't open water.
local water = {}

local PROBE_UP = 3.0
local PROBE_DOWN = 40.0

---The water surface under (x, y), probing down from `fromZ`, or nil on land.
---@param x number
---@param y number
---@param fromZ number
---@return vector3?
function water.at(x, y, fromZ)
    local top = fromZ + PROBE_UP
    local hit, surface = TestProbeAgainstWater(x, y, top, x, y, top - PROBE_DOWN)
    if not hit then return end

    local ray = StartExpensiveSynchronousShapeTestLosProbe(x, y, top, x, y, surface.z, 1, cache.ped, 7)
    local _, worldHit, point = GetShapeTestResult(ray)

    if (worldHit == 1 or worldHit == true) and point.z > surface.z + 0.15 then return end

    return surface
end

---Shore distance 0-5: how many rings of `band` metres around the point are all water.
---@param point vector3
---@param band number
---@return integer
function water.shore(point, band)
    for ring = 1, 5 do
        local radius = ring * band

        for step = 0, 7 do
            local angle = step * math.pi / 4
            local x, y = point.x + math.cos(angle) * radius, point.y + math.sin(angle) * radius

            if not water.at(x, y, point.z) then return ring - 1 end
        end
    end

    return 5
end

---The water point straight ahead of the ped, `distance` metres away, or nil.
---@param distance number
---@return vector3?
function water.ahead(distance)
    local coords = GetEntityCoords(cache.ped)
    local forward = GetEntityForwardVector(cache.ped)
    local x, y = coords.x + forward.x * distance, coords.y + forward.y * distance

    return water.at(x, y, coords.z)
end

return water
