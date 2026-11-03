-- Who may open a stash or shop: job/gang grade and distance, in the forms ox_inventory accepted them.

local access = {}

---ox_inventory accepts a group name, a list of names, or name -> grade.
---@param groups unknown
---@return table<string, integer>?
function access.toGroups(groups)
    if type(groups) == 'string' then return { [groups] = 0 } end
    if type(groups) ~= 'table' then return end

    local result = {}

    for key, value in pairs(groups) do
        if type(key) == 'number' then
            result[value] = 0
        else
            result[key] = tonumber(value) or 0
        end
    end

    return next(result) and result or nil
end

---@param coords unknown a vector, or a list of them
---@return vector3[]?
function access.toCoords(coords)
    local kind = type(coords)

    if kind == 'vector3' or kind == 'vector4' then
        return { vec3(coords.x, coords.y, coords.z) }
    elseif kind == 'table' and coords[1] then
        local list = {}

        for i, point in ipairs(coords) do
            list[i] = vec3(point.x, point.y, point.z)
        end

        return list
    end
end

---@param src integer
---@param groups? table<string, integer>
---@param minGrade? integer a higher grade than the group's own, e.g. for one shop item
---@return boolean
function access.inGroup(src, groups, minGrade)
    if not groups then return true end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end

    for _, group in ipairs({ player.PlayerData.job, player.PlayerData.gang }) do
        local required = group and groups[group.name]

        if required and (group.grade and group.grade.level or 0) >= math.max(required, minGrade or 0) then
            return true
        end
    end

    return false
end

---@param src integer
---@param coords? vector3[]
---@param distance number
---@return boolean
function access.isNear(src, coords, distance)
    if not coords then return true end

    local position = GetEntityCoords(GetPlayerPed(src))

    for _, point in ipairs(coords) do
        if #(position - point) <= distance then return true end
    end

    return false
end

return access
