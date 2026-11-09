lib.locale()

Config = {}

-- Officers of this job on duty count for store robberies and raise the ATM payout
Config.PoliceJob = 'police'

-- Staff with this ACE may start a store robbery without enough police (with a notice, written to the staff log)
Config.StaffAce = 'group.support'

Config.Atm = {
    item = 'c4',
    models = { `prop_atm_01`, `prop_atm_02`, `prop_atm_03`, `prop_fleeca_atm` },
    plantSeconds = 15,
    fuseSeconds = 15,
    -- The same ATM (anything within sameDistance metres) can't be blown again for this long
    cooldownSeconds = 120,
    sameDistance = 3.0,
    maxDistance = 2.5,
    explosionType = 2, -- sticky bomb
    -- V1: 0.0 = loud and visible but hurts nobody
    explosionDamage = 0.0,
    c4Prop = `prop_c4_final_green`,
}

Config.Store = {
    seconds = 60,
    cooldownSeconds = 600,
    minPolice = 2,
    -- How far from the register the robber may be when the time is up
    maxDistance = 6.0,
    targetRadius = 1.5,
}

Config.Bag = {
    model = `prop_money_bag_01`,
    minutes = 10,
    pickDistance = 2.5,
    -- Clients only spawn the prop within this many metres
    spawnDistance = 80.0,
}
