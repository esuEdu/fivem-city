-- Where a field's pick spots are. Client (props) and server (distance checks) work them out the same way.
local spots = {}

---@param field { center: vector3, rows?: integer, cols?: integer, spacing?: number, points?: vector3[] }
---@return { x: number, y: number, z: number }[]
function spots.list(field)
    if field.points then return field.points end

    local list = {}
    local rows, cols, spacing = field.rows or 1, field.cols or 1, field.spacing or 2.0
    local center = field.center

    for row = 1, rows do
        for col = 1, cols do
            list[#list + 1] = {
                x = center.x + (col - (cols + 1) / 2) * spacing,
                y = center.y + (row - (rows + 1) / 2) * spacing,
                z = center.z,
            }
        end
    end

    return list
end

---@param fieldId string
---@param index integer
---@return string
function spots.key(fieldId, index)
    return ('%s:%d'):format(fieldId, index)
end

return spots
