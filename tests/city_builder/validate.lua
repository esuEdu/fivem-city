dofile('harness.lua')

local validate = require 'shared.validate'

local function prop(fields)
    local data = { model = 'prop_bench_01a', x = 100.5, y = -200.25, z = 30.0, rx = 0, ry = 0, rz = 90 }
    for key, value in pairs(fields or {}) do data[key] = value end
    return data
end

-- Angles wrap into (-180, 180]
assert(validate.angle(190) == -170 and validate.angle(-190) == 170 and validate.angle(180) == 180 and validate.angle(720) == 0)

-- Model names
assert(validate.model('Prop_Bench_01A') == 'prop_bench_01a')
assert(validate.model('my-custom_prop') == 'my-custom_prop')
assert(not validate.model('') and not validate.model(('a'):rep(65)) and not validate.model('prop bench') and not validate.model('x;drop') and not validate.model(5))

-- A good prop, with defaults
local good = assert(validate.prop(prop({ rz = 270 })))
assert(good.model == 'prop_bench_01a' and good.rz == -90 and good.collision == true and good.group == nil)
assert(validate.prop(prop({ collision = false, group = 3 })).collision == false)
assert(validate.prop(prop({ group = 3 })).group == 3)

-- Bad ones say why
local bad = {
    { prop({ model = 'bad name' }), 'model' },
    { prop({ x = 9000 }), 'coords' },
    { prop({ z = -600 }), 'coords' },
    { prop({ y = 0 / 0 }), 'coords' },
    { prop({ x = math.huge }), 'coords' },
    { prop({ rx = 'a' }), 'rotation' },
    { prop({ rz = 0 / 0 }), 'rotation' },
    { prop({ group = 0 }), 'group' },
    { prop({ group = 1.5 }), 'group' },
    { prop({ group = 'x' }), 'group' },
    { 'nope', 'not_table' },
}

for i, case in ipairs(bad) do
    local result, reason = validate.prop(case[1])
    assert(result == nil and reason == case[2], ('bad prop %d: %s'):format(i, tostring(reason)))
end

-- Hides: unsigned hashes become signed, labels are optional
local hide = assert(validate.hide({ model = 4294967295, label = 'prop_bin_01a', x = 1, y = 2, z = 3 }))
assert(hide.model == -1 and hide.label == 'prop_bin_01a')
assert(validate.hide({ model = 123, x = 1, y = 2, z = 3 }).label == '0x0000007B')
assert(validate.hide({ model = -1, label = '<b>', x = 1, y = 2, z = 3 }).label == '0xFFFFFFFF')
assert(not validate.hide({ model = 1.5, x = 1, y = 2, z = 3 }))
assert(not validate.hide({ model = 2 ^ 33, x = 1, y = 2, z = 3 }))
assert(not validate.hide({ model = 1, x = 1, y = 2 }))

-- Group names
assert(validate.groupName('  Central Square  ') == 'Central Square')
assert(validate.groupName('<script>Park') == 'scriptPark')
assert(not validate.groupName('   ') and not validate.groupName(('a'):rep(41)) and not validate.groupName(3))

-- Group offsets
local x, y, z = validate.offset({ x = 1, y = -2.5, z = 0 }, 100)
assert(x == 1 and y == -2.5 and z == 0)
assert(not validate.offset({ x = 0, y = 0, z = 0 }, 100))
assert(not validate.offset({ x = 101, y = 0, z = 0 }, 100))
assert(not validate.offset({ x = 0 / 0, y = 0, z = 0 }, 100))
assert(not validate.offset('x', 100))
