dofile('harness.lua')

-- Inventory.transfer asks the cash hook before moving anything, and checks nothing changed while it waited
local Inventory = require 'server.inventory'

local calls = {}
local answer = true
local meddle

Inventory.cashHooks = {
    before = function(from, to, moving, swapped)
        calls[#calls + 1] = { from = from.owner, to = to.owner, name = moving.name, count = moving.count, swapped = swapped and swapped.name }

        if meddle then meddle() end
        if not answer then return false, 'cash_locked' end

        return true, function() calls[#calls + 1] = 'undo' end
    end,
    after = function() end,
}

local pocket = Inventory.new('CID1', 5, 10000)
local ground = Inventory.new('drop-1', 5, 10000)
ground.type = 'drop'

assert(pocket:add('money', 500))

-- A refused ledger move leaves both inventories untouched
answer = false
assert(select(2, Inventory.transfer(pocket, 1, ground, 1, 200)) == 'cash_locked')
assert(pocket.items[1].count == 500 and ground.items[1] == nil)

-- Accepted: the hook sees what moves, then the slots change
answer = true
assert(Inventory.transfer(pocket, 1, ground, 1, 200))
assert(pocket.items[1].count == 300 and ground.items[1].count == 200)
assert(calls[#calls].name == 'money' and calls[#calls].count == 200 and calls[#calls].from == 'CID1')

-- The slot changed while the ledger was being written: the move is undone, nothing changes
meddle = function() pocket.items[1].count = 100 end
assert(select(2, Inventory.transfer(pocket, 1, ground, 1, 50)) == 'invalid_slot')
assert(calls[#calls] == 'undo')
assert(pocket.items[1].count == 100 and ground.items[1].count == 200)
meddle = nil

-- Swapping two different stacks reports the stack coming back too
assert(pocket:add('water', 1, nil, 2))
assert(Inventory.transfer(ground, 1, pocket, 2))
assert(calls[#calls].name == 'money' and calls[#calls].swapped == 'water')
assert(pocket.items[2].name == 'money' and ground.items[1].name == 'water')

Inventory.cashHooks = nil
print('all cash hook tests passed')
