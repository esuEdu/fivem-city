-- Cash bags on the floor. Anyone may pick one up; the amount stays on the server and clients only see where they are.
local common = require 'server.common'

local bags = {}

local list = {}
local nextId = 0

local function publish()
    local public = {}

    for id, bag in pairs(list) do public[tostring(id)] = bag.coords end

    GlobalState.robberyBags = public
end

---@param kind 'atm'|'store'
---@param coords vector3
---@param amount integer
function bags.add(kind, coords, amount)
    nextId = nextId + 1
    list[nextId] = {
        coords = coords,
        amount = amount,
        reason = ('robbery-%s'):format(kind),
        expires = os.time() + Config.Bag.minutes * 60,
    }

    publish()
end

lib.callback.register('city_robbery:pickBag', function(source, id)
    local src = source
    if not exports.qbx_core:GetPlayer(src) then return false end

    id = math.tointeger(tonumber(id))
    local bag = id and list[id]
    if not bag then return false, 'bag_gone' end

    -- The bag's point is where the robber stood; the prop lies on the floor below it
    if not common.near(src, bag.coords, Config.Bag.pickDistance + 1.5) then return false, 'too_far' end
    if common.isDown(src) then return false, 'cant_now' end

    -- Off the floor first, so two players can't both be paid
    list[id] = nil
    publish()

    if not exports.qbx_core:AddMoney(src, 'cash', bag.amount, bag.reason) then
        list[id] = bag
        publish()
        return false, 'cash_refused'
    end

    lib.print.info(('city_robbery: player %s picked up a %s bag of $%d'):format(src, bag.reason, bag.amount))

    return true, bag.amount
end)

CreateThread(function()
    publish()

    while true do
        Wait(30000)

        local now, changed = os.time(), false
        for id, bag in pairs(list) do
            if bag.expires <= now then
                list[id] = nil
                changed = true
            end
        end

        if changed then publish() end
    end
end)

return bags
