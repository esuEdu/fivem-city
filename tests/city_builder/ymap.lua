dofile('harness.lua')

local ymap = require 'shared.ymap'
local geometry = require 'shared.geometry'

local function rotate(qx, qy, qz, qw, vx, vy, vz)
    -- v' = q v q*
    local tx = 2 * (qy * vz - qz * vy)
    local ty = 2 * (qz * vx - qx * vz)
    local tz = 2 * (qx * vy - qy * vx)

    return vx + qw * tx + (qy * tz - qz * ty), vy + qw * ty + (qz * tx - qx * tz), vz + qw * tz + (qx * ty - qy * tx)
end

-- No rotation, and a plain heading
local x, y, z, w = ymap.quaternion(0, 0, 0)
assert(near(x, 0) and near(y, 0) and near(z, 0) and near(w, 1))
x, y, z, w = ymap.quaternion(0, 0, 90)
assert(near(x, 0) and near(y, 0) and near(z, math.sqrt(0.5)) and near(w, math.sqrt(0.5)))

-- A prop's front (+Y) points where a camera with the same pitch and heading looks
for _, case in ipairs({ { 0, 0, 45 }, { 30, 0, 120 }, { -60, 0, -100 }, { 15, 40, 200 } }) do
    local qx, qy, qz, qw = ymap.quaternion(case[1], case[2], case[3])
    local fx, fy, fz = rotate(qx, qy, qz, qw, 0, 1, 0)
    local gx, gy, gz = geometry.forward(case[1], case[3])
    assert(near(fx, gx) and near(fy, gy) and near(fz, gz), 'forward')
    assert(near(qx * qx + qy * qy + qz * qz + qw * qw, 1), 'unit')
end

-- Roll turns around the prop's own front: its up leans right for a positive roll
local qx, qy, qz, qw = ymap.quaternion(0, 30, 0)
local ux, uy, uz = rotate(qx, qy, qz, qw, 0, 0, 1)
assert(near(ux, math.sin(math.rad(30))) and near(uy, 0) and near(uz, math.cos(math.rad(30))))

-- File names
assert(ymap.fileName('Central Square!') == 'cb_central_square')
assert(ymap.fileName('***') == 'cb_group')
assert(ymap.fileName(('a'):rep(60)) == 'cb_' .. ('a'):rep(40))

-- The XML: one entity per prop, the rotation stored inverted, extents around the props
local xml = ymap.build('cb_test', {
    { model = 'prop_bench_01a', x = 10, y = 20, z = 30, rx = 0, ry = 0, rz = 90 },
    { model = 'prop_bin_05a', x = -5.5, y = 2, z = 31.25, rx = 0, ry = 0, rz = 0 },
}, { lodDist = 150, exportedBy = 'Staff <b>', time = '2026-11-08 12:00' })

assert(xml:find('<CMapData>', 1, true) and xml:find('</CMapData>', 1, true))
assert(select(2, xml:gsub('<Item type="CEntityDef">', '')) == 2)
assert(xml:find('<archetypeName>prop_bench_01a</archetypeName>', 1, true))
assert(xml:find('<position x="10" y="20" z="30" />', 1, true))
assert(xml:find('<rotation x="0" y="0" z="-0.707107" w="0.707107" />', 1, true))
assert(xml:find('<rotation x="0" y="0" z="0" w="1" />', 1, true))
assert(xml:find('<entitiesExtentsMin x="-5.5" y="2" z="30" />', 1, true))
assert(xml:find('<streamingExtentsMax x="160" y="170" z="181.25" />', 1, true))
assert(xml:find('<exportedBy>Staff &lt;b&gt;</exportedBy>', 1, true))

assert(ymap.build('cb_empty', {}, { lodDist = 100 }):find('<entities />', 1, true))
