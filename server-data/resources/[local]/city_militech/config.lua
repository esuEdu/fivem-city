Config = {}

-- The tool: not used up, opens the tuner from the driver seat of any car
Config.Item = 'militech_tuning'

-- The car must be stopped (metres per second) to open the tuner and to apply a setup
Config.MaxSpeed = 1.0

-- Seconds between two applied setups, and between two "load this car's setup" requests
Config.ApplyCooldown = 2
Config.LoadCooldown = 1

-- Tabs of the tuner, in order
Config.Groups = {
    { id = 'tires', label = 'Tires' },
    { id = 'gearing', label = 'Gearing' },
    { id = 'alignment', label = 'Alignment' },
    { id = 'antiroll', label = 'Anti-roll bars' },
    { id = 'springs', label = 'Springs' },
    { id = 'damping', label = 'Damping' },
    { id = 'aero', label = 'Aero' },
    { id = 'brakes', label = 'Brakes' },
    { id = 'engine', label = 'Engine' },
}

-- Every slider. Its value is a change from the car's own handling (0 = stock), checked on the server against
-- min/max/step. Each effect changes one CHandlingData field:
--   pct = k     field * (1 + value * k)
--   add = k     field + value * k
--   pctAbs = k  field * (1 - |value| * k)  (moving a balance costs a little of the total, both ways)
-- unit: how the page shows it ('pct' change, 'front' balance, 'cm', 'int', 'num').
-- Ranges are kept tight on purpose (Forza style): setups trade one thing for another, real power comes from the
-- mechanic's engine upgrades.
Config.Params = {
    { id = 'gripBalance', group = 'tires', label = 'Grip balance', left = 'Rear', right = 'Front', min = -0.08, max = 0.08, step = 0.01, unit = 'front',
        help = 'Moves tire grip between the axles. More front grip turns in harder; more rear grip keeps the tail planted.',
        effects = { { field = 'fTractionBiasFront', add = 1 }, { field = 'fTractionCurveMax', pctAbs = 0.25 } } },
    { id = 'gripPeak', group = 'tires', label = 'Peak grip', left = 'Less', right = 'More', min = -0.04, max = 0.04, step = 0.005, unit = 'pct',
        help = 'Maximum grip of the tire compound before it starts to slide.',
        effects = { { field = 'fTractionCurveMax', pct = 1 } } },
    { id = 'gripSlide', group = 'tires', label = 'Sliding grip', left = 'Drift', right = 'Grip', min = -0.15, max = 0.08, step = 0.01, unit = 'pct',
        help = 'Grip left once the tire is sliding. Lower it for drift setups, raise it to recover from slides.',
        effects = { { field = 'fTractionCurveMin', pct = 1 } } },
    { id = 'slipAngle', group = 'tires', label = 'Slip angle', left = 'Sharp', right = 'Progressive', min = -0.15, max = 0.15, step = 0.01, unit = 'pct',
        help = 'Angle at which the tire reaches peak grip. Sharp reacts fast but breaks away suddenly; progressive is easier to catch.',
        effects = { { field = 'fTractionCurveLateral', pct = 1 } } },
    { id = 'launchSpin', group = 'tires', label = 'Launch wheelspin', left = 'Hooked', right = 'Smoky', min = -0.3, max = 1.0, step = 0.05, unit = 'pct',
        help = 'How easily the driven wheels spin at low speed.',
        effects = { { field = 'fLowSpeedTractionLossMult', pct = 1 } } },
    { id = 'offroad', group = 'tires', label = 'Off-road grip loss', left = 'Less', right = 'More', min = -0.2, max = 0.3, step = 0.05, unit = 'pct',
        help = 'Grip lost on dirt, grass and sand.',
        effects = { { field = 'fTractionLossMult', pct = 1 } } },

    { id = 'finalDrive', group = 'gearing', label = 'Final drive', left = 'Speed', right = 'Acceleration', min = -0.1, max = 0.1, step = 0.01, unit = 'pct',
        help = 'Shorter gearing pulls harder but tops out sooner; longer gearing reaches a higher top speed.',
        effects = { { field = 'fInitialDriveForce', pct = 0.6 }, { field = 'fInitialDriveMaxFlatVel', pct = -0.6 } } },
    { id = 'gears', group = 'gearing', label = 'Number of gears', left = 'Fewer', right = 'More', min = -2, max = 2, step = 1, unit = 'int',
        help = 'Gears in the gearbox. More gears keep the engine in its power band.',
        effects = { { field = 'nInitialDriveGears', add = 1 } } },
    { id = 'shiftUp', group = 'gearing', label = 'Upshift speed', left = 'Slow', right = 'Fast', min = -0.3, max = 0.5, step = 0.05, unit = 'pct',
        help = 'How fast the clutch changes up a gear.',
        effects = { { field = 'fClutchChangeRateScaleUpShift', pct = 1 } } },
    { id = 'shiftDown', group = 'gearing', label = 'Downshift speed', left = 'Slow', right = 'Fast', min = -0.3, max = 0.5, step = 0.05, unit = 'pct',
        help = 'How fast the clutch changes down a gear.',
        effects = { { field = 'fClutchChangeRateScaleDownShift', pct = 1 } } },

    { id = 'steering', group = 'alignment', label = 'Steering lock', left = 'Narrow', right = 'Wide', min = -0.15, max = 0.15, step = 0.01, unit = 'pct',
        help = 'Maximum angle of the front wheels. Wide helps drifts and tight corners; narrow is calmer at speed.',
        effects = { { field = 'fSteeringLock', pct = 1 } } },
    { id = 'camber', group = 'alignment', label = 'Camber', left = 'Soft', right = 'Stiff', min = -0.2, max = 0.2, step = 0.02, unit = 'num',
        help = 'How much the wheels lean into corners under load.',
        effects = { { field = 'fCamberStiffnesss', add = 1 } } },

    { id = 'antiRoll', group = 'antiroll', label = 'Stiffness', left = 'Soft', right = 'Stiff', min = -0.5, max = 0.8, step = 0.05, unit = 'pct',
        help = 'Resists body roll in corners. Stiff is sharper on smooth roads, soft keeps grip over bumps.',
        effects = { { field = 'fAntiRollBarForce', pct = 1 } } },
    { id = 'antiRollBalance', group = 'antiroll', label = 'Balance', left = 'Rear', right = 'Front', min = -0.15, max = 0.15, step = 0.01, unit = 'front',
        help = 'Stiffer at the front adds understeer, stiffer at the rear adds oversteer.',
        effects = { { field = 'fAntiRollBarBiasFront', add = 1 } } },
    { id = 'rollFront', group = 'antiroll', label = 'Roll centre front', left = 'Low', right = 'High', min = -0.1, max = 0.1, step = 0.01, unit = 'num',
        help = 'Higher roll centre leans less at the front.',
        effects = { { field = 'fRollCentreHeightFront', add = 1 } } },
    { id = 'rollRear', group = 'antiroll', label = 'Roll centre rear', left = 'Low', right = 'High', min = -0.1, max = 0.1, step = 0.01, unit = 'num',
        help = 'Higher roll centre leans less at the rear.',
        effects = { { field = 'fRollCentreHeightRear', add = 1 } } },

    { id = 'springs', group = 'springs', label = 'Spring rate', left = 'Soft', right = 'Stiff', min = -0.3, max = 0.4, step = 0.05, unit = 'pct',
        help = 'Stiff springs respond faster and lean less; soft springs soak up bumps and kerbs.',
        effects = { { field = 'fSuspensionForce', pct = 1 } } },
    { id = 'springBalance', group = 'springs', label = 'Balance', left = 'Rear', right = 'Front', min = -0.1, max = 0.1, step = 0.01, unit = 'front',
        help = 'Moves spring stiffness between the axles.',
        effects = { { field = 'fSuspensionBiasFront', add = 1 } } },
    { id = 'rideHeight', group = 'springs', label = 'Ride height', left = 'Low', right = 'High', min = -0.05, max = 0.06, step = 0.005, unit = 'cm',
        help = 'Lower sits the car closer to the road for less roll; higher clears bumps and off-road.',
        effects = { { field = 'fSuspensionRaise', add = 1 } } },

    { id = 'bump', group = 'damping', label = 'Bump stiffness', left = 'Soft', right = 'Stiff', min = -0.4, max = 0.6, step = 0.05, unit = 'pct',
        help = 'How hard the dampers resist compressing.',
        effects = { { field = 'fSuspensionCompDamp', pct = 1 } } },
    { id = 'rebound', group = 'damping', label = 'Rebound stiffness', left = 'Soft', right = 'Stiff', min = -0.4, max = 0.6, step = 0.05, unit = 'pct',
        help = 'How hard the dampers resist extending after a bump.',
        effects = { { field = 'fSuspensionReboundDamp', pct = 1 } } },

    { id = 'downforce', group = 'aero', label = 'Downforce', left = 'Speed', right = 'Cornering', min = -0.2, max = 0.4, step = 0.05, unit = 'pct',
        help = 'More downforce presses the car into the road at speed, at the cost of drag and top speed.',
        effects = { { field = 'fDownforceModifier', pct = 1 }, { field = 'fInitialDragCoeff', pct = 0.15 } } },

    { id = 'brakeBalance', group = 'brakes', label = 'Balance', left = 'Rear', right = 'Front', min = -0.1, max = 0.1, step = 0.01, unit = 'front',
        help = 'Front-biased brakes are stable; rear-biased brakes rotate the car into corners.',
        effects = { { field = 'fBrakeBiasFront', add = 1 }, { field = 'fBrakeForce', pctAbs = 0.2 } } },
    { id = 'brakePressure', group = 'brakes', label = 'Pressure', left = 'Low', right = 'High', min = -0.15, max = 0.05, step = 0.01, unit = 'pct',
        help = 'Overall brake force. Lower pressure locks the wheels less easily.',
        effects = { { field = 'fBrakeForce', pct = 1 } } },
    { id = 'handbrake', group = 'brakes', label = 'Handbrake', left = 'Soft', right = 'Hard', min = -0.4, max = 0.6, step = 0.05, unit = 'pct',
        help = 'Handbrake force for slides and hairpins.',
        effects = { { field = 'fHandBrakeForce', pct = 1 } } },

    { id = 'power', group = 'engine', label = 'Engine map', left = 'Economy', right = 'Power', min = -0.05, max = 0.05, step = 0.01, unit = 'pct',
        help = 'Engine power. Small on purpose: real power comes from the engine upgrades at the mechanic.',
        effects = { { field = 'fInitialDriveForce', pct = 1 } } },
    { id = 'topSpeed', group = 'engine', label = 'Rev limiter', left = 'Low', right = 'High', min = -0.05, max = 0.05, step = 0.01, unit = 'pct',
        help = 'Top speed the engine can reach.',
        effects = { { field = 'fInitialDriveMaxFlatVel', pct = 1 } } },
    { id = 'response', group = 'engine', label = 'Throttle response', left = 'Lazy', right = 'Snappy', min = -0.2, max = 0.2, step = 0.02, unit = 'pct',
        help = 'How quickly the engine revs up and down.',
        effects = { { field = 'fDriveInertia', pct = 1 } } },
}
