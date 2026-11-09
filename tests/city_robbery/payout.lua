dofile('harness.lua')

local payout = require 'server.payout'
local settings = require 'server.config'

local base, per = settings.atm.base, settings.atm.perOfficer

check(payout.atm(base, per, 0) == 15000, 'no police: the base')
check(payout.atm(base, per, 1) == 18000, '+20% for one officer')
check(payout.atm(base, per, 5) == 30000, 'linear, not compound')
check(payout.atm(base, per, 50) == 165000, 'no cap')
check(payout.atm(base, per, -3) == 15000, 'never below the base')
check(payout.atm(base, per, nil) == 15000, 'missing count is zero')
check(settings.store.amount == 200000)
