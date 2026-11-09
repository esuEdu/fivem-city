dofile('harness.lua')

local fields = require('shared.fields')

-- every row is well formed and in a known tab
local groups = {}
for _, group in ipairs(Config.Groups) do groups[group.id] = true end

local ids = {}
for _, def in ipairs(fields.list) do
    local id = fields.rowId(def)
    check(not ids[id], 'duplicate row ' .. id)
    ids[id] = true
    check(groups[def.group], 'unknown group for ' .. id)
    check(def.min < def.max, 'range of ' .. id)
    check(def.soft[1] >= def.min and def.soft[2] <= def.max and def.soft[1] < def.soft[2], 'soft range of ' .. id)
    check(def.step > 0, 'step of ' .. id)
    check(not def.int or def.field:sub(1, 1) == 'n', id .. ' int fields must be n...')
    check(not def.comp or def.field:sub(1, 3) == 'vec', id .. ' vector rows must be vec...')
end

-- names: distinct
local names = fields.names()
local seen = {}
for _, name in ipairs(names) do check(not seen[name], 'duplicate name ' .. name); seen[name] = true end
check(seen.vecCentreOfMassOffset and seen.fMass and seen.fDriveBiasFront, 'extras listed')

-- valid setups
local clean = fields.validate({
    fInitialDriveForce = 2.5, nInitialDriveGears = 8, fMass = 900,
    vecCentreOfMassOffset = { x = 0, y = 0.2, z = -0.3 }, fCollisionDamageMult = 0,
})
check(clean, 'valid setup refused')
check(clean.fInitialDriveForce == 2.5 and clean.nInitialDriveGears == 8 and clean.fCollisionDamageMult == 0, 'scalars kept')
check(clean.vecCentreOfMassOffset.z == -0.3, 'vector kept')
check(next(fields.validate({})) == nil, 'empty setup')

-- refusals
check(fields.validate('x') == nil, 'non-table accepted')
check(fields.validate({ fInitialDriveForce = 11 }) == nil, 'over hard max accepted')
check(fields.validate({ fMass = 0 }) == nil, 'under hard min accepted')
check(fields.validate({ nInitialDriveGears = 5.5 }) == nil, 'fraction gears accepted')
check(fields.validate({ fNope = 1 }) == nil, 'unknown field accepted')
check(fields.validate({ fBrakeForce = 0 / 0 }) == nil, 'NaN accepted')
check(fields.validate({ fBrakeForce = math.huge }) == nil, 'inf accepted')
check(fields.validate({ fBrakeForce = '1' }) == nil, 'string accepted')
check(fields.validate({ vecCentreOfMassOffset = 1 }) == nil, 'scalar vector accepted')
check(fields.validate({ vecCentreOfMassOffset = { x = 0, y = 0 } }) == nil, 'partial vector accepted')
check(fields.validate({ vecCentreOfMassOffset = { x = 0, y = 0, z = 9 } }) == nil, 'vector out of range accepted')
check(fields.validate({ [1] = 1 }) == nil, 'numeric key accepted')

print('ok')
