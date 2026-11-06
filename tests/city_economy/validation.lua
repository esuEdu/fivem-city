dofile('harness.lua')

local validation = require 'server.validation'

local MAX = 5000000

-- Amounts: whole, positive, under the cap; anything a cheat menu might send is refused
check(validation.amount(500, MAX) == 500, 'plain amount is accepted')
check(validation.amount(MAX, MAX) == MAX, 'amount equal to the cap is accepted')
check(validation.amount(MAX + 1, MAX) == nil, 'amount over the cap is refused')
check(validation.amount(0, MAX) == nil, 'zero is refused')
check(validation.amount(-1000, MAX) == nil, 'negative is refused')
check(validation.amount(10.5, MAX) == nil, 'fraction is refused')
check(validation.amount(0.000001, MAX) == nil, 'tiny fraction is refused')
check(validation.amount(0 / 0, MAX) == nil, 'NaN is refused')
check(validation.amount(1 / 0, MAX) == nil, 'infinity is refused')
check(validation.amount(-1 / 0, MAX) == nil, 'negative infinity is refused')
check(validation.amount('500', MAX) == nil, 'numeric string is refused')
check(validation.amount(nil, MAX) == nil, 'nil is refused')
check(validation.amount({ 500 }, MAX) == nil, 'table is refused')
check(validation.amount(2 ^ 53, MAX) == nil, 'huge number is refused')

-- Ledger entries must balance and move whole, non-zero amounts
check(validation.entries({ { account = 1, delta = -100 }, { account = 2, delta = 100 } }), 'balanced posting is accepted')
check(not validation.entries({ { account = 1, delta = -100 }, { account = 2, delta = 99 } }), 'unbalanced posting is refused')
check(not validation.entries({ { account = 1, delta = 100 } }), 'one-sided posting is refused')
check(not validation.entries({ { account = 1, delta = 0 }, { account = 2, delta = 0 } }), 'zero delta is refused')
check(not validation.entries({ { account = 1, delta = -0.5 }, { account = 2, delta = 0.5 } }), 'fractional delta is refused')
check(not validation.entries({ { account = 1, delta = -100 }, { account = 1, delta = 100 } }), 'same account twice is refused')
check(not validation.entries({ { account = '1', delta = -100 }, { account = 2, delta = 100 } }), 'string account is refused')
check(not validation.entries(nil), 'nil entries are refused')

-- A player balance can't go below zero or above the cap; system accounts can go negative (the mint)
check(validation.fits(100, -100, false, 1000), 'spending everything is allowed')
check(not validation.fits(100, -101, false, 1000), 'overdraft is refused')
check(not validation.fits(900, 101, false, 1000), 'going over the balance cap is refused')
check(validation.fits(0, -500, true, 1000), 'system account may go negative')

check(validation.formatAccount('58018396') == 'LS 5801 8396', 'account number is formatted for players')

finish()
