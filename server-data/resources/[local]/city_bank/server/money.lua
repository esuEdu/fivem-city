-- Thin wrapper over city_economy postings, so every bank movement names who did it (ref = their citizenid)
local money = {}

local systemIds = {}

---@param name 'WORLD_MINT' | 'WORLD_SINK' | 'GOV_TREASURY' | 'BANK_RESERVE'
---@return integer
function money.system(name)
    systemIds[name] = systemIds[name] or exports.city_economy:BankSystemAccount(name)
    return systemIds[name]
end

---Moves money between two accounts
---@param fromId integer
---@param toId integer
---@param amount integer
---@param reason string 'bank-...'
---@param actor string? citizenid of who did it
---@param meta table?
---@return boolean ok
---@return string? error
function money.move(fromId, toId, amount, reason, actor, meta)
    local ok, result = exports.city_economy:BankPost({
        { account = fromId, delta = -amount },
        { account = toId, delta = amount },
    }, reason, actor, meta)

    return ok, not ok and result or nil
end

---Posts several legs at once (e.g. a payment split between government and police)
---@param entries { account: integer, delta: integer }[]
function money.post(entries, reason, actor, meta)
    local ok, result = exports.city_economy:BankPost(entries, reason, actor, meta)

    return ok, not ok and result or nil
end

---@param citizenid string
---@return table? personal
---@return table? cash
function money.playerAccounts(citizenid)
    local owned = exports.city_economy:BankGetOwnedAccounts(citizenid)
    local personal, cash

    for i = 1, #owned do
        if owned[i].type == 'personal' then personal = owned[i] end
        if owned[i].type == 'cash' then cash = owned[i] end
    end

    return personal, cash
end

---@param citizenid string
---@param kind string
---@return table?
function money.owned(citizenid, kind)
    local owned = exports.city_economy:BankGetOwnedAccounts(citizenid)

    for i = 1, #owned do
        if owned[i].type == kind then return owned[i] end
    end
end

---Tells an online character something (no-op when offline)
---@param citizenid string
---@param description string
---@param kind? string
function money.notify(citizenid, description, kind)
    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)

    if player then
        exports.qbx_core:Notify(player.PlayerData.source, description, kind or 'inform')
    end
end

return money
