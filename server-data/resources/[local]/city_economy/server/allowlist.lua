-- Which resource may move money, for which reason, and how much it may pay one character per hour.
-- Pure logic (time is passed in) so tests/city_economy can check it.
local allowlist = {}

local HOUR = 3600

---@param sources table<string, { reason: string, credit?: boolean, debit?: boolean, perHour?: integer }[]>
---@return table
function allowlist.new(sources)
    return { sources = sources, paid = {} }
end

---@param list table
---@param resource string
---@param reason string
---@return table? rule
local function findRule(list, resource, reason)
    local rules = list.sources[resource]

    if not rules or type(reason) ~= 'string' then return nil end

    for i = 1, #rules do
        if reason:find(rules[i].reason) then return rules[i] end
    end
end

---Credits made in the last hour by this rule to this character
---@param list table
---@param key string
---@param now integer
---@return integer
local function paidLastHour(list, key, now)
    local entries = list.paid[key]

    if not entries then return 0 end

    local total, kept = 0, {}

    for i = 1, #entries do
        if now - entries[i].time < HOUR then
            total = total + entries[i].amount
            kept[#kept + 1] = entries[i]
        end
    end

    list.paid[key] = kept

    return total
end

---@param list table
---@param resource string
---@param reason string
---@param direction 'credit' | 'debit'
---@param citizenid string
---@param amount integer
---@param now integer os.time()
---@return boolean ok
---@return string? why
function allowlist.check(list, resource, reason, direction, citizenid, amount, now)
    local rule = findRule(list, resource, reason)

    if not rule then return false, 'source not registered' end
    if not rule[direction] then return false, ('%s not allowed'):format(direction) end

    if direction == 'credit' and rule.perHour then
        local key = ('%s|%s|%s'):format(resource, rule.reason, citizenid)

        if paidLastHour(list, key, now) + amount > rule.perHour then return false, 'hourly cap reached' end
    end

    return true
end

---Remembers a credit so the hourly cap counts it
---@param list table
---@param resource string
---@param reason string
---@param citizenid string
---@param amount integer
---@param now integer
function allowlist.record(list, resource, reason, citizenid, amount, now)
    local rule = findRule(list, resource, reason)

    if not rule or not rule.perHour then return end

    local key = ('%s|%s|%s'):format(resource, rule.reason, citizenid)
    local entries = list.paid[key] or {}

    entries[#entries + 1] = { time = now, amount = amount }
    list.paid[key] = entries
end

return allowlist
