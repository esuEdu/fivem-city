dofile('harness.lua')

local regions = require 'server.regions'

check(regions.at(-1850, -1270) == 'ocean', 'Del Perro pier is ocean')
check(regions.at(1500, 4000) == 'alamo', 'Alamo Sea')
check(regions.at(1950, 350) == 'lake', 'Land Act Reservoir')
check(regions.at(-2200, 2700) == 'river', 'Zancudo River')
check(regions.at(700, -1500) == 'canal', 'LS River canal')
check(regions.at(-6000, 0) == 'deep', 'far out is the deep sea')
check(regions.at(-1200, 7900) == 'deep', 'off Paleto Bay is deep sea')

check(regions.shore('deep', 0) == 5, 'deep sea is always 5')
check(regions.shore('canal', 5) == 2, 'canal capped')
check(regions.shore('ocean', 9) == 5)
check(regions.shore('ocean', -3) == 0)
check(regions.shore('ocean', 'x') == 0)

check(regions.atSpot('canal_leviathan', 680, -1060))
check(not regions.atSpot('canal_leviathan', 0, 0))
check(not regions.atSpot('nope', 0, 0))

check(regions.water('alamo') == 'salt' and regions.water('lake') == 'fresh')

print('regions ok')
