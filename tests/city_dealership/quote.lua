dofile('harness.lua')

local quote = require 'server.quote'

local FINANCE = { minDownPct = 20, installments = { 5, 10, 15 }, interestPct = 10 }

-- A normal plan: down payment, interest on the financed part, installments add up
local plan = quote.plan(100000, 20, 10, FINANCE)
check(plan ~= nil, 'a valid plan is accepted')
check(plan.down == 20000, 'down payment is 20%')
check(plan.financed == 80000, 'the rest is financed')
check(plan.debt == 88000, 'interest is added to the financed part')
check(plan.installment * 9 + plan.last == plan.debt, 'installments add up to the debt')

-- Rounding favours the dealership and the last installment takes the rest
local odd = quote.plan(12345, 25, 15, FINANCE)
check(odd.down == 3087, 'down payment rounds up')
check(odd.debt == 9258 + 926, 'interest rounds up')
check(odd.installment * 14 + odd.last == odd.debt, 'odd installments still add up')
check(odd.last >= odd.installment, 'the last installment is never smaller')

-- Refused plans
check(quote.plan(100000, 10, 10, FINANCE) == nil, 'down payment below the minimum is refused')
check(quote.plan(100000, 95, 10, FINANCE) == nil, 'down payment above 90% is refused')
check(quote.plan(100000, 20, 7, FINANCE) == nil, 'a count not offered is refused')
check(quote.plan(100000, 20.5, 10, FINANCE) == nil, 'a fractional down payment is refused')
check(quote.plan(100000, nil, 10, FINANCE) == nil, 'a missing down payment is refused')
check(quote.plan(0, 20, 10, FINANCE) == nil, 'a free car is refused')

-- Paying off what isn't billed yet
check(quote.unissued(88000, 8800, 10, 0) == 88000, 'nothing billed: all of it')
check(quote.unissued(88000, 8800, 10, 3) == 61600, 'three billed: the rest')
check(quote.unissued(88000, 8800, 10, 10) == 0, 'all billed: nothing')

finish()
