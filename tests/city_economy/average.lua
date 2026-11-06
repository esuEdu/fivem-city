dofile('harness.lua')

local average = require 'server.average'

local DAY = 86400

check(average.balance(1000, {}, 0, DAY) == 1000, 'untouched balance is its own average')

-- The design's example: 0 for 22 hours, then 100,000 for the last 2 hours
local avg = average.balance(0, { { time = 22 * 3600, balance = 100000 } }, 0, DAY)
check(avg == 8333, 'deposit two hours before the end averages ~8,333')

-- Depositing a minute before and withdrawing right after earns almost nothing
avg = average.balance(0, { { time = DAY - 60, balance = 1000000 }, { time = DAY - 1, balance = 0 } }, 0, DAY)
check(avg < 1000, 'a one-minute deposit barely counts')

check(average.balance(500, {}, 10, 10) == 0, 'empty window is zero')

finish()
