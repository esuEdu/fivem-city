-- Statuses a player shows when an officer checks them (alcohol, smells, gunpowder...), with when each wears off.

local status = {}

---@type table<integer, table<string, integer>> player -> status -> expires (os.time)
local list = {}

status.IDS = {
    fight = true, widepupils = true, redeyes = true, weedsmell = true, gunpowder = true, chemicals = true,
    heavybreath = true, sweat = true, handbleed = true, confused = true, alcohol = true, heavyalcohol = true,
    agitated = true,
}

---@param src integer
---@param id string
---@param seconds integer
function status.add(src, id, seconds)
    list[src] = list[src] or {}
    list[src][id] = os.time() + seconds
end

---@param src integer
---@return string[]
function status.active(src)
    local out, now = {}, os.time()

    for id, expires in pairs(list[src] or {}) do
        if expires > now then out[#out + 1] = id end
    end

    return out
end

AddEventHandler('playerDropped', function()
    list[source] = nil
end)

return status
