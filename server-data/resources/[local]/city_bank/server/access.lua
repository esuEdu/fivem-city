-- Who is asking and from where. Every panel request goes through access.panel: the player must be online, at the
-- branch they opened (checked again on each request), with a registered fingerprint, and not spamming.
local schema = require 'server.schema'
local settings = require 'server.config'

local access = {}

local THROTTLE_MS = 400
local SESSION_SECONDS = 1800

local last = {}
local sessions = {}
local bankers = {}

---Whole number from client data, or nil
function access.int(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

---@param src integer
---@param key string
---@return boolean
function access.throttled(src, key)
    local now = GetGameTimer()
    local byKey = last[src] or {}

    last[src] = byKey

    if byKey[key] and now - byKey[key] < THROTTLE_MS then return true end

    byKey[key] = now
    return false
end

---@param player table
---@return string
function access.name(player)
    local info = player.PlayerData.charinfo

    return ('%s %s'):format(info.firstname, info.lastname)
end

---@param src integer
---@param coords vector3
---@param max number
---@return boolean
function access.near(src, coords, max)
    return #(GetEntityCoords(GetPlayerPed(src)) - coords) <= max
end

---Remembers which branch a player opened, so later requests can check they are still there
function access.openSession(src, branchId)
    sessions[src] = { branch = branchId, at = os.time() }
end

function access.closeSession(src)
    sessions[src] = nil
end

---@param src integer
---@return table? player
function access.atBranch(src)
    local session = sessions[src]
    local player = exports.qbx_core:GetPlayer(src)

    if not session or not player or os.time() - session.at > SESSION_SECONDS then return end

    local branch = Config.Branches[session.branch]

    if not access.near(src, branch.coords.xyz, Config.MaxDistance + 1.0) then return end

    return player, branch
end

---Admin on duty (project standard: group.admin ACE + qbx admin duty)
function access.isAdmin(src)
    return IsPlayerAceAllowed(src --[[@as string]], 'admin') and exports.qbx_core:IsOptin(src)
end

function access.loadBankers()
    local rows = MySQL.query.await('SELECT `citizenid` FROM `bank_bankers`') or {}

    bankers = {}

    for i = 1, #rows do bankers[rows[i].citizenid] = true end
end

---@param citizenid string
---@return boolean
function access.isBanker(citizenid)
    return bankers[citizenid] == true
end

---@param src integer
---@param citizenid string
---@return boolean
function access.isStaff(src, citizenid)
    return access.isBanker(citizenid) or access.isAdmin(src)
end

---Every staff action is recorded: who did what to whom
function access.audit(actor, action, target, details)
    MySQL.insert('INSERT INTO `bank_audit` (`actor`, `action`, `target`, `details`, `created_at`) VALUES (?, ?, ?, ?, ?)', {
        actor, action, tostring(target), json.encode(details or {}), os.time(),
    })
end

---Registers a panel request. handler(src, player, citizenid, ...) returns the reply table.
---@param name string
---@param handler fun(src: integer, player: table, citizenid: string, ...): table
local handlers = {}

function access.panel(name, handler)
    local function run(src, player, ...)
        local ok, result = pcall(handler, src, player, player.PlayerData.citizenid, ...)

        if not ok then
            lib.print.error(('city_bank:%s failed for %s: %s'):format(name, src, result))
            return { ok = false, error = 'failed' }
        end

        return result
    end

    lib.callback.register(('city_bank:%s'):format(name), function(source, ...)
        local src = source

        if access.throttled(src, name) then return { ok = false, error = 'busy' } end

        schema.wait()

        local player = access.atBranch(src)

        if not player then return { ok = false, error = 'far' } end
        if not exports.city_economy:HasFingerprint(player.PlayerData.citizenid) then return { ok = false, error = 'fingerprint' } end

        return run(src, player, ...)
    end)

    handlers[name] = run
end

---Opens a panel request to the phone's Wallet app too (city_bank:app:<name>), with the same handler and rules.
---@param name string
function access.allowApp(name)
    local run = handlers[name]
    if not run then return lib.print.error(('city_bank: no panel %s to open to the app'):format(name)) end

    -- The Wallet app opens the account of whoever uses the phone (BANCO_DESIGN.md 1): no branch or fingerprint, but a
    -- phone in their pockets and not down
    lib.callback.register(('city_bank:app:%s'):format(name), function(source, ...)
        local src = source

        if access.throttled(src, 'app:' .. name) then return { ok = false, error = 'busy' } end

        schema.wait()

        local player = access.onPhone(src)

        if not player then return { ok = false, error = 'no_phone' } end

        return run(src, player, ...)
    end)
end

---@param src integer
---@return table? player
function access.onPhone(src)
    local player = exports.qbx_core:GetPlayer(src)

    if not player or Player(src).state.isDead then return end
    if exports.city_inventory:GetItemCount(src, settings.app.item) < 1 then return end

    return player
end

AddEventHandler('playerDropped', function()
    last[source] = nil
    sessions[source] = nil
end)

return access
