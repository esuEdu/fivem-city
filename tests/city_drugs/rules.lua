dofile('harness.lua')

local rules = require 'server.rules'
local spots = require 'shared.spots'

---An rng that returns these numbers in order (clamped to the asked range)
local function sequence(...)
    local values, i = { ... }, 0

    return function(a, b)
        i = i + 1
        local value = values[i] or a

        return math.max(a, math.min(b, value))
    end
end

local PRICES = {
    weed_skunk = { drug = 'weed', min = 15, max = 30, maxUnits = 5 },
    cokebaggy = { drug = 'coke', min = 40, max = 70, maxUnits = 4 },
    meth = { drug = 'meth', min = 60, max = 100, maxUnits = 3 },
}

-- Chances: 0 never happens, 100 always does
check(rules.chance(0, sequence(1)) == false, '0% never happens')
check(rules.chance(100, sequence(100)) == true, '100% always happens')
check(rules.chance(30, sequence(30)) == true, 'a roll at the edge counts')
check(rules.chance(30, sequence(31)) == false, 'a roll past it does not')

-- Offers only use what the player carries and has a price
check(rules.offer({}, PRICES, sequence(1)) == nil, 'nothing carried, no offer')
check(rules.offer({ weed_skunk = 0, joint = 4 }, PRICES, sequence(1)) == nil, 'unpriced or empty items give no offer')

-- Sorted choice: cokebaggy, meth, weed_skunk
local offer = rules.offer({ weed_skunk = 10, meth = 2 }, PRICES, sequence(2, 2, 20))
check(offer.item == 'weed_skunk', 'picks from the sorted list of carried items')
check(offer.amount == 2 and offer.total == 40, 'amount times the rolled unit price')
check(offer.drug == 'weed', 'the offer says which drug it is')

-- Never more units than carried, nor than the item's maximum
local capped = rules.offer({ meth = 2 }, PRICES, sequence(1, 9, 100))
check(capped.amount == 2, 'no more than the player carries')
check(capped.total == 200, 'unit price stays inside its range')

local maxed = rules.offer({ cokebaggy = 50 }, PRICES, sequence(1, 9, 40))
check(maxed.amount == 4, 'no more than maxUnits')

-- Risk: the drug's base for the act, one point per perPoint dollars, capped at max
local WEED = { pick = 0, lab = 2, sale = 3, perPoint = 150, max = 20 }
local METH = { pick = 8, lab = 10, sale = 10, perPoint = 60, max = 60 }
check(rules.risk(WEED, 'pick') == 0, 'base chance with no money involved')
check(rules.risk(WEED, 'unknown') == 0, 'an act with no base is 0')
check(rules.risk(WEED, 'sale', 149) == 3, 'less than one point of money adds nothing')
check(rules.risk(WEED, 'sale', 300) == 5, 'every perPoint dollars adds a point')
check(rules.risk(WEED, 'sale', 100000) == 20, 'capped at max')
check(rules.risk(METH, 'sale', 420) > rules.risk(WEED, 'sale', 420), 'the same money is riskier with a harder drug')
check(rules.risk(METH, 'sale', 3000) > rules.risk(METH, 'sale', 420), 'more money, more risk')
check(rules.risk({ sale = 5 }, 'sale', 1000) == 5, 'no perPoint means a flat chance')

-- Recipes
check(rules.canMake({ cannabis = 4 }, { cannabis = 4 }) == true, 'exact inputs are enough')
check(rules.canMake({ cannabis = 3 }, { cannabis = 4 }) == false, 'one short is not')
check(rules.canMake({ coke_small_brick = 5 }, { coke_small_brick = 2, coca_leaf = 1 }) == false, 'every input is needed')

-- Deal orders
local ORDERS = {
    { drug = 'weed', item = 'weed_brick', min = 1, max = 2, pricePerUnit = 600 },
    { drug = 'meth', item = 'meth', min = 10, max = 20, pricePerUnit = 90 },
}
check(rules.order({}, sequence(1)) == nil, 'no orders, no deal')

local order = rules.order(ORDERS, sequence(2, 15))
check(order.item == 'meth' and order.amount == 15 and order.payout == 1350, 'payout is amount times the unit price')
check(order.drug == 'meth', 'the order says which drug it is')

-- Spots: a grid centred on the field, keyed by field and index
local grid = spots.list({ center = { x = 100, y = 200, z = 30 }, rows = 2, cols = 3, spacing = 2.0 })
check(#grid == 6, 'rows times cols spots')
check(grid[1].x == 98 and grid[1].y == 199 and grid[1].z == 30, 'first spot is at the corner')
check(grid[6].x == 102 and grid[6].y == 201, 'last spot is at the opposite corner')

local listed = { { x = 1, y = 2, z = 3 } }
check(spots.list({ center = { x = 0, y = 0, z = 0 }, points = listed }) == listed, 'explicit points win over the grid')
check(spots.key('weed', 3) == 'weed:3', 'spot keys')

finish()
