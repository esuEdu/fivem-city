---Job names must be lower case (top level table key)
---@type table<string, Job>
return {
    ['unemployed'] = {
        label = 'Civilian',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Freelancer',
                payment = 10
            },
        },
    },
    ['police'] = {
        label = 'LSPD',
        type = 'leo',
        defaultDuty = false, -- fivem-city: officers clock in at a station (city_police); BCSO and SASP removed
        offDutyPay = false,
        -- fivem-city: military police ranks; the Coronel owns the police, the Tenente-Coronel also manages (city_police)
        grades = {
            [0] = { name = 'Recruta', payment = 50 },
            [1] = { name = 'Soldado', payment = 60 },
            [2] = { name = 'Cabo', payment = 70 },
            [3] = { name = 'Terceiro Sargento', payment = 80 },
            [4] = { name = 'Segundo Sargento', payment = 90 },
            [5] = { name = 'Primeiro Sargento', payment = 100 },
            [6] = { name = 'Subtenente', payment = 110 },
            [7] = { name = 'Aspirante', payment = 120 },
            [8] = { name = 'Segundo Tenente', payment = 130 },
            [9] = { name = 'Primeiro Tenente', payment = 140 },
            [10] = { name = 'Capitão', payment = 150 },
            [11] = { name = 'Major', payment = 165 },
            [12] = { name = 'Tenente-Coronel', payment = 180 },
            [13] = { name = 'Coronel', isboss = true, bankAuth = true, payment = 200 },
        },
    },
    ['ambulance'] = {
        label = 'EMS',
        type = 'ems',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'Paramedic',
                payment = 75
            },
            [2] = {
                name = 'Doctor',
                payment = 100
            },
            [3] = {
                name = 'Surgeon',
                payment = 125
            },
            [4] = {
                name = 'Chief',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['mechanic'] = {
        label = 'Mechanic',
        type = 'mechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'Novice',
                payment = 75
            },
            [2] = {
                name = 'Experienced',
                payment = 100
            },
            [3] = {
                name = 'Advanced',
                payment = 125
            },
            [4] = {
                name = 'Manager',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
}
