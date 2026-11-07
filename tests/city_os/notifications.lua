dofile('harness.lua')

local notifications = require 'server.notifications'

-- Title required; long text is cut; only a table for `open`
assert(notifications.validate({}) == nil)
assert(notifications.validate('hi') == nil)

local note = assert(notifications.validate({ app = 'police_mdt', title = ('t'):rep(100), body = ('b'):rep(300), banner = 'yes', open = 'x' }))
assert(#note.title == 80 and #note.body == 200 and note.banner == false and note.open == nil)

local second = assert(notifications.validate({ title = 'Paycheck', open = { tab = 'dispatch' } }))
assert(second.id > note.id and second.open.tab == 'dispatch' and second.body == '')

-- Newest first, at most Config.MaxNotifications
for i = 1, Config.MaxNotifications + 5 do
    notifications.add('ABC', assert(notifications.validate({ title = 'n' .. i })))
end

local list = notifications.list('ABC')
assert(#list == Config.MaxNotifications and list[1].title == 'n' .. (Config.MaxNotifications + 5))

notifications.clear('ABC')
assert(#notifications.list('ABC') == 0)

-- Badges: zero removes them
notifications.setBadge('ABC', 'police_mdt', 3)
assert(notifications.badges('ABC').police_mdt == 3)
notifications.setBadge('ABC', 'police_mdt', 0)
assert(notifications.badges('ABC').police_mdt == nil)
