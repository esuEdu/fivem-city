Config = {}

-- The tool: not used up. Only works for players who also have Config.Ace.
Config.Item = 'staff_militech'
Config.Ace = 'group.admin'

-- The car must be stopped (metres per second) to open the tuner and to apply a setup
Config.MaxSpeed = 1.0

-- Seconds between two applied setups, and between two "load this car's setup" requests
Config.ApplyCooldown = 1
Config.LoadCooldown = 1

-- Tabs, in order (fields are in shared/fields.lua)
Config.Groups = {
    { id = 'engine', label = 'Engine' },
    { id = 'gearing', label = 'Gearing' },
    { id = 'drivetrain', label = 'Drivetrain' },
    { id = 'tires', label = 'Tires' },
    { id = 'alignment', label = 'Alignment' },
    { id = 'springs', label = 'Springs' },
    { id = 'damping', label = 'Damping' },
    { id = 'antiroll', label = 'Anti-roll bars' },
    { id = 'aero', label = 'Aero' },
    { id = 'brakes', label = 'Brakes' },
    { id = 'weight', label = 'Weight' },
    { id = 'damage', label = 'Damage' },
}
