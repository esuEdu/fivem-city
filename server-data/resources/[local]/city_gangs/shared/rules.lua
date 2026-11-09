-- Plain rules with no game calls, so tests can run them: who in a gang may do what to whom.
local rules = {}

---Whether a member of `grade` may do `action` (Config.Permissions: action -> lowest grade; missing = off)
---@param permissions table<string, integer>
---@param grade integer
---@param action string
---@return boolean
function rules.can(permissions, grade, action)
    local lowest = permissions[action]

    return lowest ~= nil and grade >= lowest
end

---Every action and whether this grade may do it, for the app
---@param permissions table<string, integer>
---@param grade integer
---@return table<string, boolean>
function rules.permissions(permissions, grade)
    local list = {}

    for action in pairs(permissions) do list[action] = rules.can(permissions, grade, action) end

    return list
end

---Whether one member may act on another: only on someone below them, never on themselves
---@param myGrade integer
---@param targetGrade integer
---@param isSelf boolean
---@return boolean
function rules.outranks(myGrade, targetGrade, isSelf)
    return not isSelf and targetGrade < myGrade
end

---Whether a member may move someone to `newGrade`: it must exist, differ from the current one, and stay below their own
---@param myGrade integer
---@param targetGrade integer
---@param newGrade integer
---@param grades table<integer, table> the gang's grades
---@return boolean
function rules.canSetGrade(myGrade, targetGrade, newGrade, grades)
    if grades[newGrade] == nil or newGrade == targetGrade then return false end

    return newGrade < myGrade and targetGrade < myGrade
end

---Whether a member may leave: a boss can't if they are the gang's only boss (it would have nobody to run it)
---@param isBoss boolean
---@param bossCount integer bosses in the gang, them included
---@return boolean
function rules.canLeave(isBoss, bossCount)
    return not isBoss or bossCount > 1
end

---A period the app asked for, if it is one of `periods`, else `default`
---@param value unknown
---@param periods integer[]
---@param default integer
---@return integer
function rules.period(value, periods, default)
    for _, days in ipairs(periods) do
        if value == days then return days end
    end

    return default
end

---Day-by-day totals, oldest first: rows { day = 0-based day from the window's start, action = 'sale' | 'made', total }
---@param rows table[]
---@param count integer days in the window
---@return { sale: number, made: number }[]
function rules.series(rows, count)
    local series = {}

    for i = 1, count do series[i] = { sale = 0, made = 0 } end

    for _, row in ipairs(rows) do
        local entry = series[(tonumber(row.day) or -1) + 1]

        if entry and entry[row.action] then entry[row.action] = entry[row.action] + (tonumber(row.total) or 0) end
    end

    return series
end

---Where a member places among `list` by money earned (1 = most), and their share of the gang's total in percent
---@param list { citizenid: string, earned: number }[]
---@param citizenid string
---@return integer? place
---@return integer share
function rules.standing(list, citizenid)
    local sorted, total, mine = {}, 0, 0

    for i, entry in ipairs(list) do
        sorted[i] = entry
        total = total + entry.earned
        if entry.citizenid == citizenid then mine = entry.earned end
    end

    table.sort(sorted, function(a, b) return a.earned > b.earned end)

    local place

    for i, entry in ipairs(sorted) do
        if entry.citizenid == citizenid then place = i end
    end

    return place, total > 0 and math.floor(mine / total * 100 + 0.5) or 0
end

---The day `days` ago at this time, for "last N days" numbers
---@param now integer
---@param days integer
---@return integer
function rules.since(now, days)
    return now - days * 86400
end

return rules
