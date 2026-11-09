-- Checks and item moves every part of city_drugs uses
local settings = require 'server.config'
local rules = require 'server.rules'

local common = {}

---Whether the gang runs drugs: city_gangs' Config.Gangs, or any gang when city_gangs isn't running
---@param gang table? qbx PlayerData.gang
---@return boolean
local function isDrugGang(gang)
    if not gang or gang.name == 'none' then return false end
    if GetResourceState('city_gangs') ~= 'started' then return true end

    return exports.city_gangs:IsDrugGang(gang.name) == true
end

---The player, if they can deal right now: alive, not cuffed, not a cop on duty, and in a drug gang when `act` is gang-only
---@param src integer
---@param act? 'labs' | 'deals'
---@return table?
---@return string? reason
function common.player(src, act)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local metadata = player.PlayerData.metadata
    if metadata.isdead or metadata.inlaststand or metadata.ishandcuffed then return end

    local job = player.PlayerData.job
    if job and job.onduty and settings.blockedJobTypes[job.type] then return end

    if act and settings.gangOnly[act] and not isDrugGang(player.PlayerData.gang) then return nil, 'gang' end

    return player
end

---@param src integer
---@param coords vector3
---@param distance number
---@return boolean
function common.near(src, coords, distance)
    local ped = GetPlayerPed(src)

    return ped ~= 0 and #(GetEntityCoords(ped) - vec3(coords.x, coords.y, coords.z)) <= distance
end

---@param kind 'corner' | 'deal'
---@return boolean
function common.enoughPolice(kind)
    local needed = settings.minPolice[kind] or 0

    return needed <= 0 or exports.qbx_core:GetDutyCountType('leo') >= needed
end

---Rolls the drug's risk for an act and, if it hits, calls the police (MDT dispatch) when city_police is running
---@param drug string
---@param act 'pick' | 'lab' | 'sale' | 'refuse'
---@param title string
---@param coords vector3
---@param total? number dollars the act made
function common.alert(drug, act, title, coords, total)
    local risk = settings.drugs[drug]
    if not risk or not rules.chance(rules.risk(risk, act, total), math.random) then return end
    if GetResourceState('city_police') ~= 'started' then return end

    exports.city_police:Alert({ title = title, text = locale('alert_text'), coords = vec3(coords.x, coords.y, coords.z), code = '10-31' })
end

---Tells the Gang app (city_gangs) what a member made or sold, for its numbers
---@param src integer
---@param kind 'sale' | 'made'
---@param drug string
---@param amount integer dollars for a sale, units for a batch
function common.record(src, kind, drug, amount)
    if GetResourceState('city_gangs') ~= 'started' then return end

    exports.city_gangs:Record(src, { kind = kind, drug = drug, amount = amount })
end

---@param src integer
---@param items string[]
---@return table<string, integer>
function common.counts(src, items)
    return exports.city_inventory:Search(src, 'count', items) or {}
end

---Takes `inputs` and gives `outputs`, or does nothing if any part can't be done
---@param src integer
---@param inputs table<string, integer>
---@param outputs table<string, integer>
---@return boolean
function common.exchange(src, inputs, outputs)
    for item, count in pairs(inputs) do
        if exports.city_inventory:GetItemCount(src, item) < count then return false end
    end

    -- weight is checked with the inputs still on the player, so this errs on the safe side
    for item, count in pairs(outputs) do
        if not exports.city_inventory:CanCarryItem(src, item, count) then return false, 'full' end
    end

    local taken = {}

    for item, count in pairs(inputs) do
        if not exports.city_inventory:RemoveItem(src, item, count) then
            for back, backCount in pairs(taken) do exports.city_inventory:AddItem(src, back, backCount) end
            return false
        end

        taken[item] = count
    end

    for item, count in pairs(outputs) do
        exports.city_inventory:AddItem(src, item, count)
    end

    return true
end

-- Timed actions (picking, lab batches): the client plays the progress bar, the server holds the clock
local pending = {}

---@param src integer
---@param key string
---@param seconds number
function common.start(src, key, seconds)
    pending[src] = { key = key, readyAt = GetGameTimer() + math.floor(seconds * 1000 * 0.9) }
end

---Whether `key` was started by this player and its time has passed. Clears it either way.
---@param src integer
---@param key string
---@return boolean
function common.finish(src, key)
    local action = pending[src]
    pending[src] = nil

    return action ~= nil and action.key == key and GetGameTimer() >= action.readyAt
end

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)

return common
