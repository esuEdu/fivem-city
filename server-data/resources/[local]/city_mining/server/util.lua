-- Small helpers the server files share.
local gear = require 'shared.gear'

local util = {}

---@param src integer
---@return table? player
---@return string? citizenid
function util.player(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    return player, player.PlayerData.citizenid
end

---@param src integer
---@param coords vector3|vector4
---@param range number
---@return boolean
function util.near(src, coords, range)
    local ped = GetPlayerPed(src)

    return ped ~= 0 and #(GetEntityCoords(ped) - vec3(coords.x, coords.y, coords.z)) <= range
end

---@param src integer
---@param key string
---@param kind? string
---@param ... any locale arguments
function util.notify(src, key, kind, ...)
    exports.qbx_core:Notify(src, locale(key, ...), kind or 'inform')
end

---@param src integer
---@return string "First Last"
function util.name(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return '?' end

    local charinfo = player.PlayerData.charinfo

    return ('%s %s'):format(charinfo.firstname, charinfo.lastname)
end

---Whether the player carries a licence card of their own that hasn't expired.
---@param src integer
---@param citizenid string
---@param item string licence item
---@return boolean valid
---@return integer? expires
function util.licence(src, citizenid, item)
    local best

    for _, slot in pairs(exports.city_inventory:GetSlotsWithItem(src, item) or {}) do
        local metadata = slot.metadata or {}

        if metadata.citizenid == citizenid and type(metadata.expires) == 'number' then
            best = math.max(best or 0, metadata.expires)
        end
    end

    return best ~= nil and best > os.time(), best
end

---Whether the police granted this character the explosives licence (MDT, qbx metadata.licences.explosives).
---@param player table
---@return boolean
function util.explosivesGranted(player)
    local licences = player.PlayerData.metadata.licences

    return type(licences) == 'table' and licences.explosives == true
end

---Takes money for something the server priced: cash first, then bank.
---@param src integer
---@param amount integer
---@param reason string city_economy reason
---@return boolean
function util.pay(src, amount, reason)
    if amount <= 0 then return true end

    if exports.qbx_core:GetMoney(src, 'cash') >= amount then
        return exports.qbx_core:RemoveMoney(src, 'cash', amount, reason) == true
    end

    if exports.qbx_core:GetMoney(src, 'bank') >= amount then
        return exports.qbx_core:RemoveMoney(src, 'bank', amount, reason) == true
    end

    return false
end

---Gives items if they all fit; nothing is given otherwise.
---@param src integer
---@param drops { item: string, count: integer, metadata?: table }[]
---@return boolean
function util.giveAll(src, drops)
    for _, drop in ipairs(drops) do
        if drop.count > 0 and not exports.city_inventory:CanCarryItem(src, drop.item, drop.count, drop.metadata) then return false end
    end

    for _, drop in ipairs(drops) do
        if drop.count > 0 then exports.city_inventory:AddItem(src, drop.item, drop.count, drop.metadata) end
    end

    return true
end

---@param src integer
---@param item string
---@return integer
function util.count(src, item)
    return exports.city_inventory:GetItemCount(src, item) or 0
end

---Slots holding an item, optionally only stamped ingots.
---@param src integer
---@param name string
---@param stampedOnly? boolean
---@return table[] slots
---@return integer total
local function slotsOf(src, name, stampedOnly)
    local list, total = {}, 0

    for _, slot in pairs(exports.city_inventory:GetSlotsWithItem(src, name) or {}) do
        if not stampedOnly or (slot.metadata and slot.metadata.stamped) then
            list[#list + 1] = slot
            total = total + slot.count
        end
    end

    return list, total
end

---@param src integer
---@param name string
---@param stampedOnly? boolean
---@return integer
function util.countOf(src, name, stampedOnly)
    local _, total = slotsOf(src, name, stampedOnly)

    return total
end

---Takes a list of inputs if all of them are there; nothing is taken otherwise.
---@param src integer
---@param inputs { [1]: string, [2]: integer }[] name, count
---@param stampedOnly? table<string, boolean> names that must be stamped
---@return boolean
function util.takeAll(src, inputs, stampedOnly)
    for _, input in ipairs(inputs) do
        if input[2] > 0 and util.countOf(src, input[1], stampedOnly and stampedOnly[input[1]]) < input[2] then return false end
    end

    for _, input in ipairs(inputs) do
        local left = input[2]
        local slots = slotsOf(src, input[1], stampedOnly and stampedOnly[input[1]])

        for _, slot in ipairs(slots) do
            if left <= 0 then break end

            local take = math.min(left, slot.count)
            if exports.city_inventory:RemoveItem(src, input[1], take, nil, slot.slot) then left = left - take end
        end
    end

    return true
end

---The best pickaxe the player carries that still has durability.
---@param src integer
---@return table? slot
---@return table? pickaxe gear.pickaxes entry
function util.bestPickaxe(src)
    local best, bestGear

    for _, item in pairs(exports.city_inventory:GetInventoryItems(src) or {}) do
        local pickaxe = gear.pickaxes[item.name]

        if pickaxe then
            local durability = tonumber(item.metadata and item.metadata.durability) or pickaxe.durability
            if durability > 0 and (not bestGear or pickaxe.tier > bestGear.tier) then
                best, bestGear = item, pickaxe
            end
        end
    end

    return best, bestGear
end

---A tool slot with durability left (the pan).
---@param src integer
---@param name string
---@return table? slot
function util.tool(src, name)
    local max = gear.durability(name)

    for _, slot in pairs(exports.city_inventory:GetSlotsWithItem(src, name) or {}) do
        local durability = tonumber(slot.metadata and slot.metadata.durability) or max
        if durability > 0 then return slot end
    end
end

---Takes durability off a tool; gloves save some of it.
---@param src integer
---@param slot table
---@param amount number
function util.wear(src, slot, amount)
    local max = gear.durability(slot.name)
    if not max then return end

    local metadata = slot.metadata or {}
    local durability = (tonumber(metadata.durability) or max) - amount
    metadata.durability = math.max(0, math.floor(durability * 100 + 0.5) / 100)
    metadata.description = locale('durability_text', math.floor(metadata.durability), max)
    exports.city_inventory:SetMetadata(src, slot.slot, metadata)

    if metadata.durability <= 0 then util.notify(src, 'tool_broken', 'error') end
end

---Whether the player can't work right now: down, cuffed or driving.
---@param src integer
---@param player table
---@return string? reason
function util.unable(src, player)
    if Player(src).state['qbx_medical:deathState'] and Player(src).state['qbx_medical:deathState'] > 1 then return 'unable' end
    if player.PlayerData.metadata.ishandcuffed then return 'unable' end

    local ped = GetPlayerPed(src)
    if GetVehiclePedIsIn(ped, false) ~= 0 then return 'in_vehicle' end
end

---@return string
function util.today()
    return os.date('%Y-%m-%d')
end

return util
