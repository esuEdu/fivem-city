dofile('harness.lua')

local allowlistLib = require 'server.allowlist'

local list = allowlistLib.new({
    qbx_core = {
        { reason = '^paycheck$', credit = true, perHour = 1000 },
    },
    city_inventory = {
        { reason = '^shop%-', debit = true },
    },
})

local CID = 'ABC12345'
local now = 1000000

-- Unknown sources and reasons are refused
check(not allowlistLib.check(list, 'qbx_taxijob', 'taxi', 'credit', CID, 100, now), 'unregistered resource is refused')
check(not allowlistLib.check(list, 'qbx_core', 'unknown', 'credit', CID, 100, now), 'unregistered reason is refused')
check(not allowlistLib.check(list, 'qbx_core', nil, 'credit', CID, 100, now), 'missing reason is refused')
check(not allowlistLib.check(list, 'qbx_core', 'xpaycheck', 'credit', CID, 100, now), 'reason pattern is anchored')

-- Direction must match the rule
check(allowlistLib.check(list, 'city_inventory', 'shop-water', 'debit', CID, 100, now), 'shop charge is allowed')
check(not allowlistLib.check(list, 'city_inventory', 'shop-water', 'credit', CID, 100, now), 'shop cannot pay out')
check(not allowlistLib.check(list, 'qbx_core', 'paycheck', 'debit', CID, 100, now), 'paycheck cannot charge')

-- Hourly cap per character
check(allowlistLib.check(list, 'qbx_core', 'paycheck', 'credit', CID, 600, now), 'first paycheck is allowed')
allowlistLib.record(list, 'qbx_core', 'paycheck', CID, 600, now)
check(not allowlistLib.check(list, 'qbx_core', 'paycheck', 'credit', CID, 600, now + 60), 'paycheck over the hourly cap is refused')
check(allowlistLib.check(list, 'qbx_core', 'paycheck', 'credit', CID, 400, now + 60), 'paycheck up to the cap is allowed')
check(allowlistLib.check(list, 'qbx_core', 'paycheck', 'credit', 'OTHER', 1000, now + 60), 'cap is per character')
check(allowlistLib.check(list, 'qbx_core', 'paycheck', 'credit', CID, 1000, now + 3601), 'cap resets after an hour')

finish()
