-- One work session per player (a vein being mined, a pan being shaken), shared by mine.lua and panning.lua.
local session = {}

---@type table<integer, table> src -> session
local active = {}
local nextId = 0

-- Seconds of room for latency when checking how long a session took
local LATENCY = 1.5

---@param src integer
---@param kind string 'vein' or 'pan'
---@param data table
---@return integer id
function session.open(src, kind, data)
    nextId = nextId + 1
    data.id = nextId
    data.kind = kind
    data.started = GetGameTimer()
    active[src] = data

    return nextId
end

---Takes the player's session if it matches, so it can only finish once.
---@param src integer
---@param kind string
---@param id unknown
---@return table?
function session.take(src, kind, id)
    local current = active[src]
    if not current or current.kind ~= kind or current.id ~= id then return end

    active[src] = nil

    return current
end

---@param src integer
function session.clear(src)
    active[src] = nil
end

---Whether a session ran at least `seconds` (less a little latency) and at most `max`.
---@param current table
---@param seconds number
---@param max number
---@return boolean
function session.timed(current, seconds, max)
    local elapsed = (GetGameTimer() - current.started) / 1000

    return elapsed >= seconds - LATENCY and elapsed <= max
end

return session
