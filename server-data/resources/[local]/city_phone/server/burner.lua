-- Burner phones (made in prison, city_prison): the same phone, but with a number of its own that tells nobody who you
-- are, calls always hidden and only Config.BurnerApps. The number lives in the item's metadata, so it stays with the
-- burner. Phone and Messages ask this file which number a player is using right now.

local burner = {}

-- Player(src).state.phoneBurner = the burner number in use, set only here
local STATE = 'phoneBurner'

-- Burner numbers have 11 digits starting with 000; qbx_core's own numbers have 10, so they never clash
local function newNumber()
    local inUse = {}
    for _, id in ipairs(GetPlayers()) do
        local number = Player(tonumber(id)).state[STATE]
        if number then inUse[number] = true end
    end

    for _ = 1, 20 do
        local number = ('000%08d'):format(math.random(0, 99999999))
        if not inUse[number] then return number end
    end
end

---@param src integer
---@param number string
---@return boolean
local function holds(src, number)
    return exports.city_inventory:GetItemCount(src, Config.BurnerItem, { number = number }) > 0
end

---The burner number a player is using, if they still carry that burner
---@param src integer
---@return string?
function burner.of(src)
    local number = Player(src).state[STATE]
    if type(number) ~= 'string' then return end

    if not holds(src, number) then
        Player(src).state:set(STATE, nil, true)
        return
    end

    return number
end

exports.qbx_core:CreateUseableItem(Config.BurnerItem, function(source, item)
    local src = source
    if Player(src).state.isDead or type(item) ~= 'table' then return false end

    local metadata = type(item.metadata) == 'table' and item.metadata or {}
    local number = metadata.number

    if type(number) ~= 'string' then
        number = newNumber()
        if not number then return false end

        metadata.number = number
        exports.city_inventory:SetMetadata(src, item.slot, metadata)
    end

    Player(src).state:set(STATE, number, true)
    TriggerClientEvent('city_phone:client:toggle', src, true)

    return false
end)

---Using the normal phone again ends burner mode
function burner.stop(src)
    if Player(src).state[STATE] then Player(src).state:set(STATE, nil, true) end
end

---@param src integer
---@return string number the player is reachable on now
function burner.number(src)
    local number = burner.of(src)
    if number then return number end

    local player = exports.qbx_core:GetPlayer(src)
    return player and tostring(player.PlayerData.charinfo.phone or '') or ''
end

---@param number string
---@return integer? src of the player whose phone answers this number now
function burner.source(number)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if Player(src).state[STATE] == number and burner.of(src) then return src end
    end

    local player = exports.qbx_core:GetPlayerByPhone(number)
    local src = player and player.PlayerData.source

    -- Someone on their burner can't be reached on their own number
    if not src or burner.of(src) then return end

    return src
end

exports('ActiveNumber', burner.number)
exports('SourceByNumber', burner.source)
exports('IsBurner', function(src) return burner.of(src) ~= nil end)

---Whether the player carries the phone they are using (their own, or the burner in use)
exports('HasPhone', function(src)
    if burner.of(src) then return true end
    return exports.city_inventory:GetItemCount(src, Config.Item) > 0
end)

return burner
