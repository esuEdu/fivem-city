dofile('harness.lua')

local tuning = require('shared.tuning')
local params = Config.Params

-- every param is well formed and touches known fields
local groups = {}
for _, group in ipairs(Config.Groups) do groups[group.id] = true end

local seen = {}
for _, param in ipairs(params) do
    check(not seen[param.id], 'duplicate param ' .. param.id)
    seen[param.id] = true
    check(groups[param.group], 'unknown group for ' .. param.id)
    check(param.min < 0 and param.max > 0, 'stock (0) must be inside the range of ' .. param.id)
    check(param.step > 0, 'step of ' .. param.id)
    check(#param.effects > 0, 'effects of ' .. param.id)
    for _, effect in ipairs(param.effects) do
        check(tuning.fields[effect.field], ('%s uses unknown field %s'):format(param.id, effect.field))
        check(not tuning.fields[effect.field].readOnly, param.id .. ' writes a read-only field')
    end
end

-- validate: clean values, snapped to the step, zeros dropped
local clean = tuning.validate({ power = 0.03, gears = 1, springs = 0.12, gripPeak = 0 }, params)
check(clean, 'valid setup refused')
near(clean.power, 0.03, 'power')
check(clean.gears == 1, 'gears')
near(clean.springs, 0.1, 'springs snapped to 0.05 step')
check(clean.gripPeak == nil, 'zero kept')

-- validate: refusals
check(tuning.validate('x', params) == nil, 'non-table accepted')
check(tuning.validate({ power = 0.2 }, params) == nil, 'over max accepted')
check(tuning.validate({ power = -0.2 }, params) == nil, 'under min accepted')
check(tuning.validate({ nope = 0.01 }, params) == nil, 'unknown key accepted')
check(tuning.validate({ power = '0.01' }, params) == nil, 'string accepted')
check(tuning.validate({ power = 0 / 0 }, params) == nil, 'NaN accepted')
check(tuning.validate({ [1] = 0.01 }, params) == nil, 'numeric key accepted')
check(next(tuning.validate({}, params)) == nil, 'empty setup')

-- effective: stock untouched without settings
local stock = {
    fInitialDriveForce = 0.30, fInitialDriveMaxFlatVel = 150.0, nInitialDriveGears = 6, fBrakeForce = 1.0,
    fBrakeBiasFront = 1.3, fTractionCurveMax = 2.4, fTractionBiasFront = 0.98, fSuspensionRaise = 0.0,
    fInitialDragCoeff = 6.0, fMass = 1400.0,
}
local same = tuning.effective(stock, {}, params)
for field, value in pairs(stock) do near(same[field], value, 'unchanged ' .. field) end

-- effective: pct, add, combined effects on one field
local values = tuning.effective(stock, { power = 0.05, finalDrive = 0.1, gears = 2, rideHeight = -0.05 }, params)
near(values.fInitialDriveForce, 0.30 * 1.05 * 1.06, 'power and final drive multiply')
near(values.fInitialDriveMaxFlatVel, 150 * 0.94, 'final drive costs top speed')
check(values.nInitialDriveGears == 8, 'gears added')
near(values.fSuspensionRaise, -0.05, 'ride height')

-- gears clamp to 1-8 and stay whole numbers
check(tuning.effective({ nInitialDriveGears = 7 }, { gears = 2 }, params).nInitialDriveGears == 8, 'gears clamp')

-- balance moves cost a little total, both ways
local front = tuning.effective(stock, { brakeBalance = 0.1 }, params)
local rear = tuning.effective(stock, { brakeBalance = -0.1 }, params)
near(front.fBrakeBiasFront, 1.4, 'brake bias front')
near(front.fBrakeForce, 0.98, 'brake bias cost')
near(rear.fBrakeForce, 0.98, 'brake bias cost rear')

-- fields the car doesn't have stay absent
check(tuning.effective(stock, { downforce = 0.4 }, params).fDownforceModifier == nil, 'missing field created')

-- stats: in range, power gain raises acceleration, downforce lowers speed
local base = tuning.stats(stock)
for _, key in ipairs({ 'speed', 'acceleration', 'braking', 'handling', 'launch' }) do
    check(base[key] >= 0 and base[key] <= 10, key .. ' out of range')
end
check(base.pi >= 100 and base.pi <= 999, 'pi range')
check(tuning.stats(tuning.effective(stock, { power = 0.05 }, params)).acceleration > base.acceleration, 'power and acceleration')
check(tuning.stats(stock, { engine = 3, turbo = true }).pi > base.pi, 'upgrades raise pi')

-- classes
check(tuning.class(100) == 'D' and tuning.class(500) == 'D' and tuning.class(501) == 'C', 'class D/C')
check(tuning.class(801) == 'S1' and tuning.class(998) == 'S2' and tuning.class(999) == 'X', 'class S/X')

print('ok')
