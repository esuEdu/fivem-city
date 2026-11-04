dofile('harness.lua')
Config.CashItem = 'money'

-- qbx_core's money exports, for player 1 with 100 cash
local wallet = { [1] = 100 }
exports = {
    qbx_core = {
        GetMoney = function(_, src) return wallet[src] end,
        AddMoney = function(_, src, _, amount) wallet[src] = wallet[src] + amount return true end,
        RemoveMoney = function(_, src, _, amount)
            if wallet[src] < amount then return false end
            wallet[src] = wallet[src] - amount
            return true
        end,
    },
}

local cash = require 'server.cash'

local player = { type = 'player', id = 1 }
local stash = { type = 'stash', id = 'locker' }

-- Only a player's money item, in any case
assert(cash.is(player, 'money') and cash.is(player, 'MONEY'))
assert(not cash.is(player, 'black_money') and not cash.is(player, nil))
assert(not cash.is(stash, 'money'))

assert(cash.count(player) == 100)

-- ox_fuel paying for fuel
assert(cash.remove(player, 30) == true and wallet[1] == 70)
local ok, reason = cash.remove(player, 71)
assert(not ok and reason == 'not_enough_items' and wallet[1] == 70)

-- Bad amounts change nothing
for _, bad in ipairs({ 0, -5, 1.5, 'x' }) do
    assert(select(2, cash.remove(player, bad)) == 'invalid_count')
    assert(select(2, cash.add(player, bad)) == 'invalid_count')
end
assert(wallet[1] == 70)

assert(cash.add(player, 5) == true and wallet[1] == 75)
-- No count means one, as in ox_inventory
assert(cash.add(player) == true and wallet[1] == 76)
