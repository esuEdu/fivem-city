Config = {}

-- How close the player must stand to the banker for the server to accept a request
Config.MaxDistance = 3.0

-- Bankers are only spawned while the player is this close
Config.PedDistance = 40.0

Config.Blip = { sprite = 108, color = 2, scale = 0.8 }

-- Branches with a banker. coords = where the banker stands (z = the ped's center, like GetEntityCoords).
Config.Branches = {
    { label = 'Pacific Standard', model = `u_m_m_bankman`, coords = vector4(241.44, 227.19, 106.29, 170.43) },
    { label = 'Fleeca Hawick', model = `ig_barry`, coords = vector4(313.84, -280.58, 54.16, 338.31) },
    { label = 'Fleeca Legion Square', model = `ig_barry`, coords = vector4(149.46, -1042.09, 29.37, 335.43) },
    { label = 'Fleeca Burton', model = `ig_barry`, coords = vector4(-351.23, -51.28, 49.04, 341.73) },
    { label = 'Fleeca Del Perro', model = `ig_barry`, coords = vector4(-1211.9, -331.9, 37.78, 20.07) },
    { label = 'Fleeca Great Ocean', model = `ig_barry`, coords = vector4(-2961.14, 483.09, 15.7, 83.84) },
    { label = 'Fleeca Route 68', model = `ig_barry`, coords = vector4(1174.8, 2708.2, 38.09, 178.52) },
    { label = 'Blaine County Savings', model = `u_m_m_bankman`, coords = vector4(-112.22, 6471.01, 31.63, 134.18) },
}
