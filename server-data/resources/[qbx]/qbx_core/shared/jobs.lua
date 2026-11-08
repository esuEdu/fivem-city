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
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'Officer',
                payment = 75
            },
            [2] = {
                name = 'Sergeant',
                payment = 100
            },
            [3] = {
                name = 'Lieutenant',
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
}
