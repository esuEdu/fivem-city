-- Icons drawn in the world at places a player can use, and the key to use them. Other resources add points with
-- exports.city_points:Add and get them removed when they stop. Nothing runs per frame unless a point is within
-- Config.ShowDistance (lib.points' shared loop); a nearby point checks access and walls only every Config.CheckMs.

local theme = require '@city_ui.theme'

local TXD = 'city_points'
local GLYPH = 0.6 -- icon size inside the badge
local FONT = 4
local TEXT_SCALE = 0.36

---@param value string '#rrggbb' or 'rgba(r, g, b, a)'
---@return integer[]
local function color(value)
    local r, g, b = value:match('^#(%x%x)(%x%x)(%x%x)$')
    if r then return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), 255 } end

    local cr, cg, cb, ca = value:match('rgba%((%d+),%s*(%d+),%s*(%d+),%s*([%d.]+)%)')
    return { tonumber(cr), tonumber(cg), tonumber(cb), math.floor(tonumber(ca) * 255) }
end

local ACCENT = color(theme.accent)
local ACCENT_TEXT = color(theme.accentText)
local TEXT = color(theme.text)
local PANEL = color(theme.panel)
-- The panel color is see-through for screens; over a bright wall the badge needs more body
PANEL[4] = math.max(PANEL[4], 210)

local ICONS = {}

do
    local txd = CreateRuntimeTxd(TXD)

    for _, name in ipairs({ 'disc', 'ring' }) do
        CreateRuntimeTextureFromImage(txd, name, ('icons/%s.png'):format(name))
    end

    for _, name in ipairs(Config.Icons) do
        CreateRuntimeTextureFromImage(txd, name, ('icons/%s.png'):format(name))
        ICONS[name] = true
    end
end

---@type table<integer, table> key -> point
local points = {}
local lastKey = 0
local keyLabel = Config.Key
local keybind

---@param coords vector3 | vector4
---@param height number
---@return vector3
local function iconSpot(coords, height)
    if type(coords) == 'vector4' then
        local heading = math.rad(coords.w)
        return vec3(coords.x - math.sin(heading) * Config.Ahead, coords.y + math.cos(heading) * Config.Ahead, coords.z + height)
    end

    return vec3(coords.x, coords.y, coords.z + height)
end

---@param text string
---@param y number
---@param rgba integer[]
---@param alpha number 0-1
local function drawText(text, y, rgba, alpha)
    SetTextFont(FONT)
    SetTextScale(TEXT_SCALE, TEXT_SCALE)
    SetTextColour(rgba[1], rgba[2], rgba[3], math.floor(rgba[4] * alpha))
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, y)
end

---Refreshes access, the wall check and whether the key works here. Runs every Config.CheckMs while nearby.
---@param point table
---@param distance number
local function check(point, distance)
    if point.probe then
        local status, hit, hitCoords = GetShapeTestResult(point.probe)

        -- 1 = still running; anything else is a result (or a lost probe)
        if status ~= 1 then
            point.probe = nil
            -- Anything between the camera and the standing spot is a wall (the spot itself is open air: a player
            -- stands there), so a hit hides the icon; only a graze at the very end is let through
            point.clear = not hit or hit == 0 or #(hitCoords - point.stand) < 0.1
        end
    end

    if not point.probe then
        local cam = GetFinalRenderedCamCoord()
        local stand = point.stand
        point.probe = StartShapeTestLosProbe(cam.x, cam.y, cam.z, stand.x, stand.y, stand.z, 1, cache.ped, 7)
    end

    point.allowed = not point.canInteract or point.canInteract() == true

    local usable = point.allowed and point.clear and distance <= point.useDistance and not cache.vehicle

    -- ox_doorlock also uses E: a door in its range takes the key
    if usable and GetResourceState('ox_doorlock') == 'started' then
        local door = exports.ox_doorlock:getClosestDoor()
        if door and door.distance < door.maxDistance then usable = false end
    end

    point.usable = usable

    -- The key players bound, shown on the chip
    if usable and keybind then keyLabel = keybind:getCurrentKey() end
end

---@param point table
local function nearby(point)
    local now = GetGameTimer()
    local distance = #(GetEntityCoords(cache.ped) - point.coords)

    if now >= point.nextCheck then
        point.nextCheck = now + Config.CheckMs
        check(point, distance)
    end

    local target = (point.allowed and point.clear) and 1.0 or 0.0
    point.alpha = point.alpha + (target - point.alpha) * math.min(1.0, GetFrameTime() * 8.0)

    -- Fades out over the last quarter of the radius too (at most 1.5 m)
    local alpha = point.alpha * math.min(1.0, math.max(0.0, (point.distance - distance) / math.min(1.5, point.distance * 0.25)))
    if alpha < 0.02 then return end

    local close = 1.0 - math.min(distance / point.distance, 1.0)
    local height = Config.Size * (0.7 + 0.3 * close)
    local width = height / GetAspectRatio(false)
    local bob = math.sin(now / 500.0 + point.key) * 0.025

    SetDrawOrigin(point.coords.x, point.coords.y, point.coords.z + bob, 0)

    DrawSprite(TXD, 'disc', 0.0, 0.0, width, height, 0.0, PANEL[1], PANEL[2], PANEL[3], math.floor(PANEL[4] * alpha))
    DrawSprite(TXD, 'ring', 0.0, 0.0, width, height, 0.0, ACCENT[1], ACCENT[2], ACCENT[3], math.floor(255 * alpha))
    DrawSprite(TXD, point.icon, 0.0, 0.0, width * GLYPH, height * GLYPH, 0.0, ACCENT[1], ACCENT[2], ACCENT[3], math.floor(255 * alpha))

    if point.usable then
        local textHeight = GetRenderedCharacterHeight(TEXT_SCALE, FONT)
        local chip = height * 0.55
        local chipY = height * 0.5 + chip * 0.5 + 0.004

        DrawSprite(TXD, 'disc', 0.0, chipY, chip / GetAspectRatio(false), chip, 0.0, ACCENT[1], ACCENT[2], ACCENT[3], math.floor(255 * alpha))
        drawText(keyLabel, chipY - textHeight * 0.5, ACCENT_TEXT, alpha)
        drawText(point.label, chipY + chip * 0.5 + 0.002, TEXT, alpha)
    end

    ClearDrawOrigin()
end

---@param point table
local function onExit(point)
    point.alpha = 0.0
    point.usable = false
    point.probe = nil
end

---@param key integer
local function remove(key)
    local point = points[key]
    if not point then return end

    point:remove()
    points[key] = nil
end

---Adds a point. coords: vec4 = where the player stands, facing the thing (the icon floats a little ahead), vec3 = the
---spot itself. canInteract (optional) decides who sees and uses it; onUse runs when the key is pressed there. ped = true:
---coords are where a ped stands (pass a vec3) and the icon floats over its head; height: meters above coords otherwise.
---@param data { coords: vector3 | vector4, icon: string, label: string, onUse: function, canInteract?: function, distance?: number, useDistance?: number, height?: number, ped?: boolean }
---@return integer? key for Remove
local function add(data)
    local kind = type(data) == 'table' and type(data.coords)

    if kind ~= 'vector3' and kind ~= 'vector4' then return lib.print.error('Add: coords must be a vector3 or vector4') end
    if not ICONS[data.icon] then return lib.print.error(('Add: unknown icon %s'):format(tostring(data.icon))) end
    if type(data.label) ~= 'string' or not data.onUse then return lib.print.error('Add: label and onUse are required') end

    lastKey = lastKey + 1

    local point = lib.points.new({
        coords = iconSpot(data.coords, data.ped and Config.PedHeight or tonumber(data.height) or Config.Height),
        -- The wall check aims here, at chest height where the player stands, not at the icon: the icon floats against
        -- the shelf or mirror and a ray to it hits that thing first
        stand = vec3(data.coords.x, data.coords.y, data.coords.z + 0.3),
        distance = data.distance or (data.ped and Config.PedShowDistance) or Config.ShowDistance,
        key = lastKey,
        resource = GetInvokingResource() or cache.resource,
        icon = data.icon,
        label = data.label,
        useDistance = data.useDistance or (data.ped and Config.PedUseDistance) or Config.UseDistance,
        canInteract = data.canInteract,
        onUse = data.onUse,
        alpha = 0.0,
        nextCheck = 0,
        clear = false,
        allowed = false,
        usable = false,
        nearby = nearby,
        onExit = onExit,
    })

    points[lastKey] = point

    return lastKey
end

keybind = lib.addKeybind({
    name = 'city_points_use',
    description = 'Use the place you are at (armory, locker, wardrobe)',
    defaultKey = Config.Key,
    onPressed = function()
        local best

        for _, point in pairs(points) do
            if point.usable and point.currentDistance and (not best or point.currentDistance < best.currentDistance) then
                best = point
            end
        end

        if best then best.onUse() end
    end,
})

exports('Add', add)
exports('Remove', remove)

AddEventHandler('onClientResourceStop', function(resource)
    for key, point in pairs(points) do
        if point.resource == resource then remove(key) end
    end
end)
