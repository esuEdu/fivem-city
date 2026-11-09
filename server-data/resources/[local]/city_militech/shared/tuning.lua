-- Pure tuning rules, used by the server (checking a setup) and the client (applying it, scoring it). No natives here.
local tuning = {}

-- Every handling field the tuner reads or writes, with the bounds a setup may never cross.
-- fMass is only read, for the stats.
tuning.fields = {
    fInitialDriveForce = { min = 0.01 },
    fInitialDriveMaxFlatVel = { min = 1.0 },
    nInitialDriveGears = { int = true, min = 1, max = 8 },
    fClutchChangeRateScaleUpShift = { min = 0.1 },
    fClutchChangeRateScaleDownShift = { min = 0.1 },
    fDriveInertia = { min = 0.1 },
    fTractionCurveMax = { min = 0.1 },
    fTractionCurveMin = { min = 0.1 },
    fTractionCurveLateral = { min = 0.01 },
    fTractionBiasFront = { min = 0.01, max = 1.99 },
    fLowSpeedTractionLossMult = { min = 0.0 },
    fTractionLossMult = { min = 0.0 },
    fSteeringLock = { min = 0.01 },
    fCamberStiffnesss = {},
    fAntiRollBarForce = { min = 0.0 },
    fAntiRollBarBiasFront = { min = 0.01, max = 1.99 },
    fRollCentreHeightFront = {},
    fRollCentreHeightRear = {},
    fSuspensionForce = { min = 0.1 },
    fSuspensionBiasFront = { min = 0.01, max = 1.99 },
    fSuspensionRaise = { min = -0.2, max = 0.2 },
    fSuspensionCompDamp = { min = 0.01 },
    fSuspensionReboundDamp = { min = 0.01 },
    fDownforceModifier = { min = 0.0 },
    fInitialDragCoeff = { min = 0.1 },
    fBrakeForce = { min = 0.05 },
    fBrakeBiasFront = { min = 0.01, max = 1.99 },
    fHandBrakeForce = { min = 0.05 },
    fMass = { readOnly = true },
}

local EPSILON = 1e-6

---@param value number
---@param min number?
---@param max number?
---@return number
local function clamp(value, min, max)
    if min and value < min then return min end
    if max and value > max then return max end
    return value
end

---@param value number
---@return boolean
local function finite(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

---@param params table[]
---@return table<string, table>
function tuning.index(params)
    local byId = {}

    for i = 1, #params do
        byId[params[i].id] = params[i]
    end

    return byId
end

---Checks a setup sent by a client. Returns a clean copy (values snapped to the step, zeros dropped) or nil and the
---first bad key.
---@param settings any
---@param params table[]
---@return table<string, number>?, string?
function tuning.validate(settings, params)
    if type(settings) ~= 'table' then return nil, 'not a table' end

    local byId = tuning.index(params)
    local clean = {}

    for key, value in pairs(settings) do
        local param = type(key) == 'string' and byId[key]
        if not param then return nil, tostring(key) end
        if type(value) ~= 'number' or not finite(value) then return nil, key end
        if value < param.min - EPSILON or value > param.max + EPSILON then return nil, key end

        local steps = math.floor((value - param.min) / param.step + 0.5)
        local snapped = clamp(param.min + steps * param.step, param.min, param.max)

        -- keep the stored numbers short, so a JSON round trip gives back the same value
        snapped = math.floor(snapped * 10000 + 0.5) / 10000

        if math.abs(snapped) > EPSILON then clean[key] = snapped end
    end

    return clean
end

---The handling a setup gives, from the car's own (stock) values. Fields the car doesn't have are left out.
---@param stock table<string, number>
---@param settings table<string, number>
---@param params table[]
---@return table<string, number>
function tuning.effective(stock, settings, params)
    local values = {}

    for field, value in pairs(stock) do
        values[field] = value
    end

    for i = 1, #params do
        local param = params[i]
        local value = settings[param.id]

        if value and value ~= 0 then
            for j = 1, #param.effects do
                local effect = param.effects[j]
                local current = values[effect.field]

                if current then
                    if effect.pct then
                        current = current * (1 + value * effect.pct)
                    elseif effect.add then
                        current = current + value * effect.add
                    elseif effect.pctAbs then
                        current = current * (1 - math.abs(value) * effect.pctAbs)
                    end

                    values[effect.field] = current
                end
            end
        end
    end

    for field, value in pairs(values) do
        local rule = tuning.fields[field]

        if rule then
            value = clamp(value, rule.min, rule.max)
            if rule.int then value = math.floor(value + 0.5) end
            values[field] = value
        end
    end

    return values
end

---0-10 from where value sits between low and high
---@param value number
---@param low number
---@param high number
---@return number
local function score(value, low, high)
    return clamp((value - low) / (high - low) * 10, 0, 10)
end

local CLASSES = {
    { max = 500, name = 'D' },
    { max = 600, name = 'C' },
    { max = 700, name = 'B' },
    { max = 800, name = 'A' },
    { max = 900, name = 'S1' },
    { max = 998, name = 'S2' },
    { max = 999, name = 'X' },
}

---@param pi integer
---@return string
function tuning.class(pi)
    for i = 1, #CLASSES do
        if pi <= CLASSES[i].max then return CLASSES[i].name end
    end

    return 'X'
end

---Forza-like ratings (0-10) and performance index for a set of handling values. A display estimate only.
---@param values table<string, number>
---@param upgrades? { engine?: integer, brakes?: integer, transmission?: integer, turbo?: boolean }
---@return { speed: number, acceleration: number, braking: number, handling: number, launch: number, pi: integer, class: string }
function tuning.stats(values, upgrades)
    upgrades = upgrades or {}

    local engine = 1 + 0.05 * ((upgrades.engine or -1) + 1) + (upgrades.turbo and 0.05 or 0)
    local gearbox = 1 + 0.02 * ((upgrades.transmission or -1) + 1)
    local brakes = 1 + 0.1 * ((upgrades.brakes or -1) + 1)

    local force = (values.fInitialDriveForce or 0.25) * engine
    local flatVel = (values.fInitialDriveMaxFlatVel or 140) * gearbox
    local drag = math.max(values.fInitialDragCoeff or 5, 0.1)
    local gears = values.nInitialDriveGears or 5
    local inertia = values.fDriveInertia or 1
    local curveMax = values.fTractionCurveMax or 2.2
    local downforce = values.fDownforceModifier or 1
    local lateral = values.fTractionCurveLateral or 22
    local spin = values.fLowSpeedTractionLossMult or 1
    local antiRoll = values.fAntiRollBarForce or 0.8

    local speed = score(flatVel / drag ^ 0.1, 100, 175)
    local acceleration = score(force * (1 + (inertia - 1) * 0.15) * (1 + (gears - 5) * 0.02) * gearbox, 0.15, 0.5)
    local braking = score((values.fBrakeForce or 0.8) * brakes, 0.3, 1.6)
    local handling = score(curveMax * (1 + (downforce - 1) * 0.15) * (1 + (antiRoll - 0.8) * 0.03)
        * (1 - (lateral - 22) / 300), 1.6, 3.2)
    local launch = 0.6 * acceleration + 0.4 * score(curveMax / (1 + spin * 0.4), 1.0, 2.6)

    local weighted = speed * 0.25 + acceleration * 0.25 + handling * 0.3 + braking * 0.1 + launch * 0.1
    local pi = math.floor(clamp(100 + weighted / 10 * 899, 100, 999) + 0.5)

    local function round(value) return math.floor(value * 10 + 0.5) / 10 end

    return {
        speed = round(speed),
        acceleration = round(acceleration),
        braking = round(braking),
        handling = round(handling),
        launch = round(launch),
        pi = pi,
        class = tuning.class(pi),
    }
end

return tuning
