-- How many reports a staff member aims to close per day, week and month. Admins change them in the Team tab; they are
-- kept in the server's resource storage (KVP), and Config.Goals is the default until someone does.

local staff = require 'server.staff'

local goals = {}

local PERIODS = { 'today', 'week', 'month' }
local MAX_GOAL = 10000

---@return { today: integer, week: integer, month: integer }
function goals.get()
    local result = {}

    for _, period in ipairs(PERIODS) do
        local saved = GetResourceKvpInt(('goal:%s'):format(period))
        result[period] = saved > 0 and saved or Config.Goals[period]
    end

    return result
end

staff.register('setGoals', function(src, data)
    local values = {}

    for _, period in ipairs(PERIODS) do
        local value = math.tointeger(tonumber(data[period]))
        if not value or value < 1 or value > MAX_GOAL then return false, 'invalid' end
        values[period] = value
    end

    for period, value in pairs(values) do
        SetResourceKvpInt(('goal:%s'):format(period), value)
    end

    staff.log(src, 'setGoals', nil, ('%d / %d / %d'):format(values.today, values.week, values.month))

    return true, values
end, 'goals')

return goals
