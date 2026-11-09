dofile('harness.lua')

local records = require 'server.records'
local settings = require 'server.config'
local penal = require 'shared.penal'
local mdt = require 'server.mdt.core'
local police = require 'server.police'

-- Every crime has an id, a known category and whole, non-negative numbers
local seen = {}
local categories = {}
for _, category in ipairs(penal.categories) do categories[category] = true end

for _, crime in ipairs(penal.crimes) do
    assert(type(crime.id) == 'string' and not seen[crime.id], crime.id)
    assert(categories[crime.category], crime.id)
    for _, key in ipairs({ 'months', 'fine', 'points' }) do
        assert(math.tointeger(crime[key]) and crime[key] >= 0, crime.id .. ' ' .. key)
    end
    seen[crime.id] = true
end

-- Totals come from the penal code, counted
local charges, totals = records.total({ { id = 'speeding', count = 2 }, { id = 'resisting', count = 1 } })
assert(#charges == 2 and charges[1].title == 'Speeding' and charges[1].count == 2)
assert(totals.fine == 250 * 2 + 1000 and totals.months == 10 and totals.points == 6)

-- Caps on months and fine
local _, big = records.total({ { id = 'murder_officer', count = 5 }, { id = 'bank_robbery', count = 5 } })
assert(big.months == settings.maxMonths and big.fine == settings.maxFine)

-- Anything the page could send wrong is refused
for _, bad in ipairs({
    nil, 'speeding', {}, { { id = 'nope', count = 1 } }, { { id = 'speeding', count = 0 } },
    { { id = 'speeding', count = settings.maxCount + 1 } }, { { id = 'speeding', count = 1.5 } },
    { { id = 'speeding', count = 1 }, { id = 'speeding', count = 1 } }, { { id = 'speeding' } }, { 'speeding' },
}) do
    assert(records.total(bad) == nil)
end

local tooMany = {}
for i = 1, settings.maxCharges + 1 do tooMany[i] = { id = penal.crimes[i].id, count = 1 } end
assert(records.total(tooMany) == nil)

-- Page input checks
assert(mdt.citizenid('ABC12345') == 'ABC12345')
assert(mdt.citizenid('AB') == nil and mdt.citizenid("ABC'; DROP") == nil and mdt.citizenid(12345) == nil)
assert(mdt.plate(' lspd1234 ') == 'LSPD1234' and mdt.plate('AB 12') == 'AB 12')
assert(mdt.plate('TOOLONGPLATE') == nil and mdt.plate('AB-12') == nil and mdt.plate('') == nil)
assert(mdt.id(3) == 3 and mdt.id(0) == nil and mdt.id(-1) == nil and mdt.id(1.5) == nil and mdt.id('3') == nil)
assert(mdt.like('jo') == '%jo%' and mdt.like('j') == nil and mdt.like('50%_off') == [[%50\%\_off%]])

-- Text from players: control characters and angle brackets out, trimmed and cut
assert(police.clean('  <b>hi</b>\nthere  ', 100) == 'b hi /b there')
assert(police.clean('abcdef', 3) == 'abc' and police.clean(nil, 10) == '')
assert(police.cleanLong('line one\r\nline <two>', 100) == 'line one\nline  two')

-- Every permission names a real grade
for action, grade in pairs(Config.Permissions) do
    assert(math.tointeger(grade) and grade >= 0 and grade <= 4, action)
end


-- Sentence reductions: none, a percent off (rounded down) or a set time; anything else is refused
assert(records.reduce(40, nil) == 40)
assert(records.reduce(40, { kind = 'percent', value = 25 }) == 30)
assert(records.reduce(45, { kind = 'percent', value = 50 }) == 22)
assert(records.reduce(40, { kind = 'percent', value = 100 }) == 0)
assert(records.reduce(40, { kind = 'months', value = 12 }) == 12)
assert(records.reduce(40, { kind = 'percent', value = 101 }) == nil)
assert(records.reduce(40, { kind = 'percent', value = -5 }) == nil)
assert(records.reduce(40, { kind = 'months', value = settings.maxMonths + 1 }) == nil)
assert(records.reduce(40, { kind = 'other', value = 5 }) == nil)
assert(records.reduce(40, 'half') == nil)

print('city_police rules ok')
