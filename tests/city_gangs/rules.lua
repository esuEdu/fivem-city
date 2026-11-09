dofile('harness.lua')

local rules = require 'shared.rules'

local PERMISSIONS = { app = 0, recruit = 2, setGrade = 2, fire = 2, log = 1 }
local GRADES = { [0] = { name = 'Recruit' }, [1] = { name = 'Enforcer' }, [2] = { name = 'Shot Caller' }, [3] = { name = 'Boss', isboss = true } }

-- Grades: an action is allowed from its lowest grade up; a missing one is off for everyone
check(rules.can(PERMISSIONS, 0, 'app'), 'recruits open the app')
check(not rules.can(PERMISSIONS, 1, 'recruit'), 'enforcers cannot recruit')
check(rules.can(PERMISSIONS, 2, 'recruit') and rules.can(PERMISSIONS, 3, 'fire'), 'shot callers and bosses manage')
check(not rules.can(PERMISSIONS, 3, 'bank'), 'an unknown action is off')

local list = rules.permissions(PERMISSIONS, 1)
check(list.log == true and list.fire == false and list.app == true, 'permission list for the app')

-- Acting on others: only on lower grades, never on yourself
check(rules.outranks(3, 2, false), 'a boss manages a shot caller')
check(not rules.outranks(2, 2, false), 'not someone of the same rank')
check(not rules.outranks(2, 3, false), 'not someone above')
check(not rules.outranks(3, 0, true), 'not yourself')

-- Setting a grade: it exists, changes something, and stays below your own
check(rules.canSetGrade(3, 0, 2, GRADES), 'a boss promotes a recruit to shot caller')
check(not rules.canSetGrade(3, 0, 3, GRADES), 'nobody is made boss from the app')
check(not rules.canSetGrade(2, 0, 2, GRADES), 'a shot caller cannot make another shot caller')
check(rules.canSetGrade(2, 1, 0, GRADES), 'a shot caller demotes an enforcer')
check(not rules.canSetGrade(2, 2, 1, GRADES), 'nor demote their equal')
check(not rules.canSetGrade(3, 1, 1, GRADES), 'the same grade is no change')
check(not rules.canSetGrade(3, 1, 7, GRADES), 'a grade the gang does not have')

-- Leaving: the only boss stays
check(rules.canLeave(false, 1), 'members leave freely')
check(not rules.canLeave(true, 1), 'the only boss cannot leave')
check(rules.canLeave(true, 2), 'a boss can when there is another')

-- Periods: only the ones offered, else the default
check(rules.period(30, { 1, 7, 30 }, 7) == 30, 'an offered period')
check(rules.period(365, { 1, 7, 30 }, 7) == 7, 'anything else falls back')
check(rules.period(nil, { 1, 7, 30 }, 7) == 7, 'no period falls back')

-- Daily series: zero-filled, rows land on their day, unknown days and actions are ignored
local series = rules.series({
    { day = 0, action = 'sale', total = 100 },
    { day = 0, action = 'sale', total = '50' },
    { day = 2, action = 'made', total = 6 },
    { day = 9, action = 'sale', total = 999 },
    { day = 1, action = 'hire', total = 1 },
}, 3)
check(#series == 3, 'one entry per day')
check(series[1].sale == 150 and series[1].made == 0, 'sales add up on their day')
check(series[2].sale == 0 and series[2].made == 0, 'empty days are zero')
check(series[3].made == 6, 'units made on their day')

-- Standing: place by money earned and share of the gang's total
local ranked = {
    { citizenid = 'A', earned = 300 },
    { citizenid = 'B', earned = 600 },
    { citizenid = 'C', earned = 100 },
}
local place, share = rules.standing(ranked, 'A')
check(place == 2 and share == 30, 'second with 30%')
check(rules.standing(ranked, 'B') == 1, 'most money is first')
check(ranked[1].citizenid == 'A', 'the list given is not reordered')
local _, none = rules.standing({ { citizenid = 'A', earned = 0 } }, 'A')
check(none == 0, 'no money, no share')

check(rules.since(1000000, 7) == 1000000 - 7 * 86400, 'last N days')

finish()
