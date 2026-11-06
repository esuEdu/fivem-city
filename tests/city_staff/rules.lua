dofile('harness.lua')

local rules = require 'shared.rules'

local SUPPORT, MOD, ADMIN = 1, 2, 3

-- Levels come from the ACEs a player has; the highest wins, none is 0
assert(rules.levelOf(function() return false end) == 0)
assert(rules.levelOf(function(ace) return ace == 'support' end) == SUPPORT)
assert(rules.levelOf(function(ace) return ace == 'support' or ace == 'mod' end) == MOD)
assert(rules.levelOf(function() return true end) == ADMIN)
assert(rules.levelIndex('mod') == MOD and rules.levelIndex('nope') == 0 and rules.levelIndex(nil) == 0)

-- A level includes everything below it; not on duty (0) can do nothing
assert(rules.can(SUPPORT, 'goto') and rules.can(SUPPORT, 'warn') and rules.can(SUPPORT, 'reports'))
assert(not rules.can(SUPPORT, 'kick') and not rules.can(SUPPORT, 'spectate') and not rules.can(SUPPORT, 'inventory'))
assert(rules.can(MOD, 'kick') and rules.can(MOD, 'ban') and rules.can(MOD, 'goto'))
assert(not rules.can(MOD, 'banLong') and not rules.can(MOD, 'unban') and not rules.can(MOD, 'log') and not rules.can(MOD, 'kill'))
assert(rules.can(ADMIN, 'banLong') and rules.can(ADMIN, 'log') and rules.can(ADMIN, 'setJob'))
assert(not rules.can(0, 'app') and not rules.can(0, 'goto'))

-- An action missing from the config is off for everyone
assert(not rules.can(ADMIN, 'giveMoney'))

local permissions = rules.permissions(MOD)
assert(permissions.kick == true and permissions.log == false and permissions.app == true)

-- Ban lengths: up to Config.MaxBanHours without banLong; longer and permanent (0) need it
assert(rules.banSeconds(24, false) == 24 * 3600)
assert(rules.banSeconds(Config.MaxBanHours, false) == Config.MaxBanHours * 3600)
assert(select(2, rules.banSeconds(Config.MaxBanHours + 1, false)) == 'too_long')
assert(select(2, rules.banSeconds(0, false)) == 'too_long')
assert(rules.banSeconds(0, true) == 0)
assert(rules.banSeconds(720, true) == 720 * 3600)
assert(rules.banSeconds('24', false) == 24 * 3600)
for _, bad in ipairs({ -1, 1.5, 'abc', {}, 87601 }) do
    assert(select(2, rules.banSeconds(bad, true)) == 'invalid', tostring(bad))
end

-- Every ban length the app offers works for an admin
for _, hours in ipairs(Config.BanLengths) do
    assert(rules.banSeconds(hours, true), hours)
end

-- Text: trimmed, control characters gone, capped, nothing for empty or non-strings
assert(rules.cleanText('  hello  ', 50) == 'hello')
assert(rules.cleanText('a\nb\tc', 50) == 'a b c')
assert(rules.cleanText(('x'):rep(500), 200) == ('x'):rep(200))
assert(rules.cleanText('   ', 50) == nil and rules.cleanText(nil, 50) == nil and rules.cleanText(5, 50) == nil)

-- Ids: whole, non-negative numbers only
assert(rules.toId(3) == 3 and rules.toId('7') == 7 and rules.toId(0) == 0)
assert(rules.toId(-1) == nil and rules.toId(1.5) == nil and rules.toId('x') == nil and rules.toId(nil) == nil)

print('ok')
