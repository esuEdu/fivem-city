-- /miningpoints (staff): aim at the ground and press E to save a point for the chosen region and kind, G / H to
-- change region / kind, DEL to remove the nearest point, BACKSPACE to leave. Existing points nearby are drawn as
-- markers only while the tool is open.
local KEYS = { save = 38, region = 47, kind = 74, remove = 178, leave = 177 }
local KINDS = { 'vein', 'gravel', 'passage' }
local COLOURS = { vein = { 255, 180, 60 }, gravel = { 60, 170, 255 }, passage = { 220, 60, 60 } }

local tool

---@return vector3? hit
local function aim()
    local hit, _, coords = lib.raycast.fromCamera(1, 4, 30.0)

    return hit and coords or nil
end

local function refresh()
    local ok, list = lib.callback.await('city_mining:staff:points', false)
    if ok and tool then tool.points = list end
end

local function helpText()
    local region = tool.regions[tool.region]
    local kind = KINDS[tool.kind]

    lib.showTextUI(locale('points_help', region.label, kind), { position = 'left-center' })
end

local function close()
    tool = nil
    if lib.isTextUIOpen() then lib.hideTextUI() end
end

local function loop()
    local nextRefresh = 0

    while tool do
        Wait(0)

        local now = GetGameTimer()
        if now >= nextRefresh then
            nextRefresh = now + 5000
            CreateThread(refresh)
        end

        for _, point in ipairs(tool.points or {}) do
            local colour = COLOURS[point.kind] or COLOURS.vein
            DrawMarker(28, point.x, point.y, point.z + 0.3, 0, 0, 0, 0, 0, 0, 0.35, 0.35, 0.35, colour[1], colour[2], colour[3], 170, false, false, 2, false, nil, nil, false)
        end

        local target = aim()
        if target then
            DrawMarker(1, target.x, target.y, target.z - 0.05, 0, 0, 0, 0, 0, 0, 0.8, 0.8, 0.4, 255, 255, 255, 120, false, false, 2, false, nil, nil, false)
        end

        DisableControlAction(0, KEYS.region, true)
        DisableControlAction(0, KEYS.kind, true)

        if IsDisabledControlJustPressed(0, KEYS.region) then
            tool.region = tool.region % #tool.regions + 1
            local kind = tool.regions[tool.region].kind
            tool.kind = kind == 'gravel' and 2 or 1
            helpText()
        elseif IsDisabledControlJustPressed(0, KEYS.kind) then
            tool.kind = tool.kind % #KINDS + 1
            helpText()
        elseif IsControlJustPressed(0, KEYS.save) and target then
            local heading = GetEntityHeading(cache.ped)
            local ok, result = lib.callback.await('city_mining:staff:add', false, tool.regions[tool.region].id, KINDS[tool.kind],
                { x = target.x, y = target.y, z = target.z, w = heading })
            lib.notify({ description = ok and locale('point_added', result) or locale(result or 'invalid'), type = ok and 'success' or 'error' })
            refresh()
        elseif IsControlJustPressed(0, KEYS.remove) then
            local origin = GetEntityCoords(cache.ped)
            local nearest, best

            for _, point in ipairs(tool.points or {}) do
                local distance = #(origin - vec3(point.x, point.y, point.z))
                if distance < 6.0 and (not best or distance < best) then nearest, best = point, distance end
            end

            if nearest then
                local ok, result = lib.callback.await('city_mining:staff:remove', false, nearest.id)
                lib.notify({ description = ok and locale('point_removed', nearest.id) or locale(result or 'invalid'), type = ok and 'success' or 'error' })
                refresh()
            end
        elseif IsControlJustPressed(0, KEYS.leave) then
            close()
        end
    end
end

RegisterNetEvent('city_mining:client:pointsTool', function(regions)
    if GetInvokingResource() then return end
    if tool then return close() end
    if type(regions) ~= 'table' or #regions == 0 then return end

    tool = { regions = regions, region = 1, kind = 1, points = {} }
    helpText()
    refresh()
    CreateThread(loop)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and tool then close() end
end)
