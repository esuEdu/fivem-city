dofile('harness.lua')

local beds = require 'server.beds'
local settings = require 'server.config'

-- A bed holds one player, and a player lies in one bed
check(beds.free('pillbox') == 1, 'first bed is free')
check(beds.claim(1, 'pillbox', 1, false, 10), 'player 1 lies down')
check(not beds.claim(2, 'pillbox', 1, false, 10), 'player 2 cannot share the bed')
check(not beds.claim(1, 'pillbox', 2, false, 10), 'player 1 cannot take a second bed')
check(beds.free('pillbox') == 2, 'next free bed skips the taken one')
check(not beds.claim(3, 'nowhere', 1, false, 10), 'unknown hospital is refused')

-- No healing before the treatment time
check(not beds.finish(1), 'cannot finish right away')
clock = clock + 9
check(not beds.finish(1), 'cannot finish a second early')
clock = clock + 1
check(beds.finish(1), 'finishes once the time is up')
check(#Calls.healed == 1 and Calls.healed[1] == 1, 'player 1 is healed')
check(not beds.finish(1), 'cannot be healed twice in one stay')

-- Lying down by yourself is charged once, from the bank
check(#Calls.removeMoney == 1 and Calls.removeMoney[1].amount == settings.prices.bed, 'bed fee charged')
check(Calls.removeMoney[1].reason == 'hospital-bed', 'bed fee uses the hospital-bed reason')

-- Already paid (respawn, reception): no second charge
beds.release(1)
check(beds.free('pillbox') == 1, 'released bed is free again')
check(beds.claim(2, 'pillbox', 1, true, 5), 'player 2 lies down, already paid')
clock = clock + 5
check(beds.finish(2), 'paid stay finishes')
check(#Calls.removeMoney == 1, 'paid stay is not charged again')

-- Not enough in the bank: the fee becomes a bill
beds.release(2)
BankBalance = 0
check(beds.claim(3, 'paleto', 1, false, 1), 'player 3 lies down in Paleto')
clock = clock + 1
check(beds.finish(3), 'player 3 finishes')
check(#Calls.bills == 1 and Calls.bills[1].amount == settings.prices.bed, 'unpaid fee becomes a bill')

finish()
