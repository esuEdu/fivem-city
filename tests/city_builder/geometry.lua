dofile('harness.lua')

local geometry = require 'shared.geometry'

-- Yaw 0 looks north (+Y), yaw 90 looks west (-X); pitch 90 looks up
local x, y, z = geometry.forward(0, 0)
assert(near(x, 0) and near(y, 1) and near(z, 0))
x, y, z = geometry.forward(0, 90)
assert(near(x, -1) and near(y, 0) and near(z, 0))
x, y, z = geometry.forward(90, 0)
assert(near(x, 0) and near(y, 0) and near(z, 1))

-- Right of north is east; up is +Z when level
x, y, z = geometry.right(0)
assert(near(x, 1) and near(y, 0) and near(z, 0))
x, y, z = geometry.up(0, 0)
assert(near(x, 0) and near(y, 0) and near(z, 1))

-- The middle of the screen is straight ahead; the right edge leans right, the top leans up
x, y, z = geometry.screenRay(0, 0, 60, 16 / 9, 0.5, 0.5)
assert(near(x, 0) and near(y, 1) and near(z, 0))
x, y, z = geometry.screenRay(0, 0, 60, 16 / 9, 1, 0.5)
assert(x > 0.5 and y > 0 and near(z, 0))
assert(near(math.atan(x / y), math.atan(math.tan(math.rad(30)) * 16 / 9)))
x, y, z = geometry.screenRay(0, 0, 60, 16 / 9, 0.5, 0)
assert(near(x, 0) and near(math.deg(math.atan(z / y)), 30))

-- Rays come out normalized
x, y, z = geometry.screenRay(-35, 123, 50, 1.6, 0.2, 0.9)
assert(near(x * x + y * y + z * z, 1))

-- Arrow nudges move flat, relative to the camera
x, y = geometry.flatMove(0, 1, 0)
assert(near(x, 0) and near(y, 1))
x, y = geometry.flatMove(90, 0, 1)
assert(near(x, 0) and near(y, 1))
x, y = geometry.flatMove(180, -1, 0)
assert(near(x, 0) and near(y, 1))
