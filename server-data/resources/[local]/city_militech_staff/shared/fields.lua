-- Every handling field the staff tuner can set, as absolute values. min/max are hard limits checked on the server
-- (only there so the game can't break); soft is the slider's usual range on the page, which grows to fit the car's
-- own value. Vector fields have one row per component (comp = 'x' / 'y' / 'z').
local fields = {}

fields.list = {
    { field = 'fInitialDriveForce', group = 'engine', label = 'Drive force', min = 0, max = 10, soft = { 0.05, 1.5 }, step = 0.001,
        help = 'Engine power at the wheels. Most cars sit between 0.15 and 0.40.' },
    { field = 'fInitialDriveMaxFlatVel', group = 'engine', label = 'Top speed (flat)', min = 1, max = 1000, soft = { 50, 400 }, step = 0.5,
        help = 'Top speed on flat ground before drag. Roughly km/h with no drag.' },
    { field = 'fDriveInertia', group = 'engine', label = 'Engine inertia', min = 0.01, max = 10, soft = { 0.2, 3 }, step = 0.01,
        help = 'How fast the engine revs. Higher revs up and down faster.' },

    { field = 'nInitialDriveGears', group = 'gearing', label = 'Gears', min = 1, max = 8, soft = { 1, 8 }, step = 1, int = true,
        help = 'Number of forward gears.' },
    { field = 'fClutchChangeRateScaleUpShift', group = 'gearing', label = 'Upshift rate', min = 0.05, max = 50, soft = { 0.5, 15 }, step = 0.1,
        help = 'Clutch speed going up a gear.' },
    { field = 'fClutchChangeRateScaleDownShift', group = 'gearing', label = 'Downshift rate', min = 0.05, max = 50, soft = { 0.5, 15 }, step = 0.1,
        help = 'Clutch speed going down a gear.' },

    { field = 'fDriveBiasFront', group = 'drivetrain', label = 'Drive bias front', min = 0, max = 1, soft = { 0, 1 }, step = 0.01,
        help = '0 = rear-wheel drive, 1 = front-wheel drive, anything between = all-wheel drive with that share up front.' },

    { field = 'fTractionCurveMax', group = 'tires', label = 'Peak grip', min = 0.05, max = 20, soft = { 0.5, 5 }, step = 0.01,
        help = 'Maximum cornering grip.' },
    { field = 'fTractionCurveMin', group = 'tires', label = 'Sliding grip', min = 0.05, max = 20, soft = { 0.5, 5 }, step = 0.01,
        help = 'Grip while sliding. Lower than peak grip makes it drift.' },
    { field = 'fTractionCurveLateral', group = 'tires', label = 'Slip angle', min = 0.01, max = 90, soft = { 0.05, 1.5 }, step = 0.005,
        help = 'Angle where the tire reaches peak grip. Low = sharp, high = progressive.' },
    { field = 'fTractionSpringDeltaMax', group = 'tires', label = 'Tire sidewall flex', min = 0.01, max = 2, soft = { 0.05, 0.4 }, step = 0.005,
        help = 'How far the tire can flex sideways before it slides.' },
    { field = 'fTractionBiasFront', group = 'tires', label = 'Grip balance', min = 0.01, max = 1.99, soft = { 0.01, 1.99 }, step = 0.005, unit = 'front',
        help = 'Grip split between the axles.' },
    { field = 'fLowSpeedTractionLossMult', group = 'tires', label = 'Launch wheelspin', min = 0, max = 10, soft = { 0, 3 }, step = 0.01,
        help = 'Wheelspin at low speed. 0 = no burnouts.' },
    { field = 'fTractionLossMult', group = 'tires', label = 'Off-road grip loss', min = 0, max = 10, soft = { 0, 3 }, step = 0.01,
        help = 'Grip lost on dirt, grass and sand.' },

    { field = 'fSteeringLock', group = 'alignment', label = 'Steering lock', min = 0.01, max = 90, soft = { 0.1, 1.5 }, step = 0.005,
        help = 'Maximum angle of the front wheels.' },
    { field = 'fCamberStiffnesss', group = 'alignment', label = 'Camber stiffness', min = -5, max = 5, soft = { -1, 1 }, step = 0.01,
        help = 'How much the wheels lean under load.' },

    { field = 'fSuspensionForce', group = 'springs', label = 'Spring rate', min = 0, max = 50, soft = { 0.3, 8 }, step = 0.01,
        help = 'Spring stiffness.' },
    { field = 'fSuspensionBiasFront', group = 'springs', label = 'Spring balance', min = 0.01, max = 1.99, soft = { 0.01, 1.99 }, step = 0.005, unit = 'front',
        help = 'Spring stiffness split between the axles.' },
    { field = 'fSuspensionRaise', group = 'springs', label = 'Ride height', min = -1, max = 1, soft = { -0.2, 0.2 }, step = 0.005, unit = 'm',
        help = 'Raises or lowers the body. Negative is lower.' },
    { field = 'fSuspensionUpperLimit', group = 'springs', label = 'Travel up', min = -1, max = 1, soft = { -0.1, 0.3 }, step = 0.005, unit = 'm',
        help = 'How far the wheel can move up into the body.' },
    { field = 'fSuspensionLowerLimit', group = 'springs', label = 'Travel down', min = -1, max = 1, soft = { -0.3, 0.1 }, step = 0.005, unit = 'm',
        help = 'How far the wheel can drop down.' },

    { field = 'fSuspensionCompDamp', group = 'damping', label = 'Bump', min = 0, max = 50, soft = { 0.1, 6 }, step = 0.01,
        help = 'Damping while the suspension compresses.' },
    { field = 'fSuspensionReboundDamp', group = 'damping', label = 'Rebound', min = 0, max = 50, soft = { 0.1, 8 }, step = 0.01,
        help = 'Damping while the suspension extends.' },

    { field = 'fAntiRollBarForce', group = 'antiroll', label = 'Anti-roll stiffness', min = 0, max = 20, soft = { 0, 4 }, step = 0.01,
        help = 'Resists body roll in corners.' },
    { field = 'fAntiRollBarBiasFront', group = 'antiroll', label = 'Anti-roll balance', min = 0.01, max = 1.99, soft = { 0.01, 1.99 }, step = 0.005, unit = 'front',
        help = 'Anti-roll split between the axles.' },
    { field = 'fRollCentreHeightFront', group = 'antiroll', label = 'Roll centre front', min = -2, max = 2, soft = { -0.5, 0.8 }, step = 0.01, unit = 'm',
        help = 'Higher leans less at the front.' },
    { field = 'fRollCentreHeightRear', group = 'antiroll', label = 'Roll centre rear', min = -2, max = 2, soft = { -0.5, 0.8 }, step = 0.01, unit = 'm',
        help = 'Higher leans less at the rear.' },

    { field = 'fInitialDragCoeff', group = 'aero', label = 'Drag', min = 0, max = 200, soft = { 0, 30 }, step = 0.1,
        help = 'Air drag. Lower = higher top speed.' },
    { field = 'fDownforceModifier', group = 'aero', label = 'Downforce', min = 0, max = 100, soft = { 0, 10 }, step = 0.05,
        help = 'Grip from air pressure at speed.' },

    { field = 'fBrakeForce', group = 'brakes', label = 'Brake force', min = 0, max = 20, soft = { 0, 4 }, step = 0.01,
        help = 'Overall brake force.' },
    { field = 'fBrakeBiasFront', group = 'brakes', label = 'Brake balance', min = 0.01, max = 1.99, soft = { 0.01, 1.99 }, step = 0.005, unit = 'front',
        help = 'Brake split between the axles.' },
    { field = 'fHandBrakeForce', group = 'brakes', label = 'Handbrake', min = 0, max = 20, soft = { 0, 4 }, step = 0.01,
        help = 'Handbrake force.' },

    { field = 'fMass', group = 'weight', label = 'Mass', min = 1, max = 100000, soft = { 200, 10000 }, step = 1, unit = 'kg',
        help = 'Weight of the car.' },
    { field = 'vecCentreOfMassOffset', comp = 'x', group = 'weight', label = 'Centre of mass side', min = -5, max = 5, soft = { -1, 1 }, step = 0.01, unit = 'm',
        help = 'Moves the centre of mass left (−) or right (+).' },
    { field = 'vecCentreOfMassOffset', comp = 'y', group = 'weight', label = 'Centre of mass front', min = -5, max = 5, soft = { -1, 1 }, step = 0.01, unit = 'm',
        help = 'Moves the centre of mass back (−) or forward (+).' },
    { field = 'vecCentreOfMassOffset', comp = 'z', group = 'weight', label = 'Centre of mass height', min = -5, max = 5, soft = { -1, 1 }, step = 0.01, unit = 'm',
        help = 'Lower (−) leans and flips less.' },
    { field = 'vecInertiaMultiplier', comp = 'x', group = 'weight', label = 'Inertia pitch', min = 0.01, max = 10, soft = { 0.2, 3 }, step = 0.01,
        help = 'Resistance to nosing up and down.' },
    { field = 'vecInertiaMultiplier', comp = 'y', group = 'weight', label = 'Inertia roll', min = 0.01, max = 10, soft = { 0.2, 3 }, step = 0.01,
        help = 'Resistance to rolling sideways.' },
    { field = 'vecInertiaMultiplier', comp = 'z', group = 'weight', label = 'Inertia yaw', min = 0.01, max = 10, soft = { 0.2, 3 }, step = 0.01,
        help = 'Resistance to spinning around.' },

    { field = 'fCollisionDamageMult', group = 'damage', label = 'Collision damage', min = 0, max = 10, soft = { 0, 3 }, step = 0.05,
        help = 'Damage taken from crashes. 0 = none.' },
    { field = 'fDeformationDamageMult', group = 'damage', label = 'Body deformation', min = 0, max = 10, soft = { 0, 3 }, step = 0.05,
        help = 'How much the body dents.' },
    { field = 'fWeaponDamageMult', group = 'damage', label = 'Weapon damage', min = 0, max = 10, soft = { 0, 3 }, step = 0.05,
        help = 'Damage taken from gunfire.' },
    { field = 'fEngineDamageMult', group = 'damage', label = 'Engine damage', min = 0, max = 10, soft = { 0, 3 }, step = 0.05,
        help = 'How fast the engine wears from damage.' },
}

---Row id on the page: the field, or field.comp for vector components
---@param def table
---@return string
function fields.rowId(def)
    return def.comp and ('%s.%s'):format(def.field, def.comp) or def.field
end

---Distinct field names, for reading the car's stock values
---@return string[]
function fields.names()
    local seen, names = {}, {}

    for i = 1, #fields.list do
        local name = fields.list[i].field

        if not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end

    return names
end

local scalars, vectors = {}, {}

for i = 1, #fields.list do
    local def = fields.list[i]

    if def.comp then
        vectors[def.field] = vectors[def.field] or {}
        vectors[def.field][def.comp] = def
    else
        scalars[def.field] = def
    end
end

---@param value any
---@param def table
---@return number?
local function number(value, def)
    if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then return end
    if value < def.min or value > def.max then return end
    if def.int then
        if value ~= math.floor(value) then return end
        return value
    end

    return math.floor(value * 100000 + 0.5) / 100000
end

---Checks a staff setup sent by a client: field = number, or field = { x =, y =, z = } for vectors.
---Returns a clean copy, or nil and the first bad field.
---@param values any
---@return table?, string?
function fields.validate(values)
    if type(values) ~= 'table' then return nil, 'not a table' end

    local clean = {}

    for field, value in pairs(values) do
        if type(field) ~= 'string' then return nil, tostring(field) end

        if scalars[field] then
            local checked = number(value, scalars[field])
            if not checked then return nil, field end
            clean[field] = checked
        elseif vectors[field] then
            if type(value) ~= 'table' then return nil, field end

            local vector = {}

            for _, comp in ipairs({ 'x', 'y', 'z' }) do
                local checked = vectors[field][comp] and number(value[comp], vectors[field][comp])
                if not checked then return nil, ('%s.%s'):format(field, comp) end
                vector[comp] = checked
            end

            clean[field] = vector
        else
            return nil, field
        end
    end

    return clean
end

return fields
