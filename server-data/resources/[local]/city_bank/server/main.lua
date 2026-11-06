-- Branch requests. The client only says which branch it is at; who the player is comes from source,
-- and the server checks they really stand at that banker before showing anything.
local COOLDOWN_MS = 750

local lastRequest = {}

---@param src integer
---@return boolean
local function throttled(src)
    local now = GetGameTimer()

    if lastRequest[src] and now - lastRequest[src] < COOLDOWN_MS then return true end

    lastRequest[src] = now
    return false
end

---@param src integer
---@param branchId unknown
---@return table? player
local function playerAtBranch(src, branchId)
    local player = exports.qbx_core:GetPlayer(src)

    if not player then return end

    local branch = type(branchId) == 'number' and math.tointeger(branchId) and Config.Branches[branchId]

    if not branch then
        exports.city_economy:Flag(src, 'bank_bad_branch', 3, { branch = tostring(branchId) })
        return
    end

    local distance = #(GetEntityCoords(GetPlayerPed(src)) - branch.coords.xyz)

    if distance > Config.MaxDistance then
        lib.print.warn(('city_bank: source %s asked branch %s from %.1fm away'):format(src, branchId, distance))
        return
    end

    return player
end

---@param player table
---@return table
local function overviewFor(player)
    local overview = exports.city_economy:GetAccountOverview(player.PlayerData.citizenid)

    if not overview then return { ok = false } end

    overview.ok = true
    overview.firstname = player.PlayerData.charinfo.firstname

    return overview
end

-- Opening the panel. Before the first fingerprint only the name is sent: no balance, no history.
lib.callback.register('city_bank:open', function(source, branchId)
    local src = source

    if throttled(src) then return { ok = false, error = 'busy' } end

    local player = playerAtBranch(src, branchId)

    if not player then return { ok = false, error = 'far' } end

    if not exports.city_economy:HasFingerprint(player.PlayerData.citizenid) then
        return { ok = true, fingerprint = false, firstname = player.PlayerData.charinfo.firstname }
    end

    return overviewFor(player)
end)

lib.callback.register('city_bank:registerFingerprint', function(source, branchId)
    local src = source

    if throttled(src) then return { ok = false, error = 'busy' } end

    local player = playerAtBranch(src, branchId)

    if not player then return { ok = false, error = 'far' } end

    exports.city_economy:RegisterFingerprint(player.PlayerData.citizenid)

    return overviewFor(player)
end)

AddEventHandler('playerDropped', function()
    lastRequest[source] = nil
end)
