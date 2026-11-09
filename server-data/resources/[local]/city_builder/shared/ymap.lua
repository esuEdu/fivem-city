-- Turns placed props into a CodeWalker ymap XML (CMapData), so a group built in game becomes a real map file.
-- Plain Lua (tested in tests/city_builder/).
local ymap = {}

local rad, sin, cos = math.rad, math.sin, math.cos

---The world rotation of a prop (degrees, GTA rotation order 2: roll, then pitch, then yaw) as a quaternion.
---@return number x
---@return number y
---@return number z
---@return number w
function ymap.quaternion(pitch, roll, yaw)
    local hp, hr, hy = rad(pitch) / 2, rad(roll) / 2, rad(yaw) / 2
    local cp, sp = cos(hp), sin(hp)
    local cr, sr = cos(hr), sin(hr)
    local cy, sy = cos(hy), sin(hy)

    -- qz(yaw) * qx(pitch) * qy(roll)
    local x = cy * sp * cr - sy * cp * sr
    local y = cy * cp * sr + sy * sp * cr
    local z = sy * cp * cr + cy * sp * sr
    local w = cy * cp * cr - sy * sp * sr

    return x, y, z, w
end

---A ymap/file name from a group name: lowercase letters, digits and _.
function ymap.fileName(name)
    local clean = tostring(name):lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    if clean == '' then clean = 'group' end

    return ('cb_%s'):format(clean:sub(1, 40))
end

local function num(value)
    local text = ('%.6f'):format(value):gsub('0+$', ''):gsub('%.$', '')
    if text == '-0' then text = '0' end

    return text
end

local function vec(tag, x, y, z, w)
    if w then
        return ('<%s x="%s" y="%s" z="%s" w="%s" />'):format(tag, num(x), num(y), num(z), num(w))
    end

    return ('<%s x="%s" y="%s" z="%s" />'):format(tag, num(x), num(y), num(z))
end

local function escape(text)
    return (tostring(text):gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'):gsub('"', '&quot;'))
end

---@param name string ymap name (from ymap.fileName)
---@param props table[] { model, x, y, z, rx, ry, rz }
---@param options { lodDist: number, exportedBy?: string, time?: string }
---@return string xml
function ymap.build(name, props, options)
    local lodDist = options.lodDist
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    local entities = {}

    for _, prop in ipairs(props) do
        minX, minY, minZ = math.min(minX, prop.x), math.min(minY, prop.y), math.min(minZ, prop.z)
        maxX, maxY, maxZ = math.max(maxX, prop.x), math.max(maxY, prop.y), math.max(maxZ, prop.z)

        -- ymaps keep the inverse of the world rotation (as CodeWalker reads and writes them)
        local qx, qy, qz, qw = ymap.quaternion(prop.rx, prop.ry, prop.rz)

        entities[#entities + 1] = table.concat({
            '    <Item type="CEntityDef">',
            ('      <archetypeName>%s</archetypeName>'):format(escape(prop.model)),
            '      <flags value="32" />',
            '      <guid value="0" />',
            '      ' .. vec('position', prop.x, prop.y, prop.z),
            '      ' .. vec('rotation', -qx, -qy, -qz, qw),
            '      <scaleXY value="1" />',
            '      <scaleZ value="1" />',
            '      <parentIndex value="-1" />',
            ('      <lodDist value="%s" />'):format(num(lodDist)),
            '      <childLodDist value="0" />',
            '      <lodLevel>LODTYPES_DEPTH_ORPHANHD</lodLevel>',
            '      <numChildren value="0" />',
            '      <priorityLevel>PRI_REQUIRED</priorityLevel>',
            '      <extensions />',
            '      <ambientOcclusionMultiplier value="255" />',
            '      <artificialAmbientOcclusion value="255" />',
            '      <tintValue value="0" />',
            '    </Item>',
        }, '\n')
    end

    if #props == 0 then minX, minY, minZ, maxX, maxY, maxZ = 0, 0, 0, 0, 0, 0 end

    return table.concat({
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<CMapData>',
        ('  <name>%s</name>'):format(escape(name)),
        '  <parent />',
        '  <flags value="0" />',
        '  <contentFlags value="1" />',
        '  ' .. vec('streamingExtentsMin', minX - lodDist, minY - lodDist, minZ - lodDist),
        '  ' .. vec('streamingExtentsMax', maxX + lodDist, maxY + lodDist, maxZ + lodDist),
        '  ' .. vec('entitiesExtentsMin', minX, minY, minZ),
        '  ' .. vec('entitiesExtentsMax', maxX, maxY, maxZ),
        #entities > 0 and ('  <entities>\n%s\n  </entities>'):format(table.concat(entities, '\n')) or '  <entities />',
        '  <containerLods />',
        '  <boxOccluders />',
        '  <occludeModels />',
        '  <physicsDictionaries />',
        '  <instancedData>',
        '    <ImapLink />',
        '    <PropInstanceList />',
        '    <GrassInstanceList />',
        '  </instancedData>',
        '  <timeCycleModifiers />',
        '  <carGenerators />',
        '  <block>',
        '    <version value="0" />',
        '    <flags value="0" />',
        ('    <name>%s</name>'):format(escape(name)),
        ('    <exportedBy>%s</exportedBy>'):format(escape(options.exportedBy or 'city_builder')),
        '    <owner />',
        ('    <time>%s</time>'):format(escape(options.time or '')),
        '  </block>',
        '</CMapData>',
        '',
    }, '\n')
end

return ymap
