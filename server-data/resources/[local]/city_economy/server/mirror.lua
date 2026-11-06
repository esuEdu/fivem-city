-- qbx_core keeps a read-only copy of cash and bank (PlayerData.money) for the HUD and old scripts.
-- The ledger is the truth; this pushes the real balances into that copy.
local accounts = require 'server.accounts'

local mirror = {}

---@param src integer
---@param citizenid string
function mirror.sync(src, citizenid)
    local personal, cash = accounts.ensurePlayer(citizenid)

    if not personal or not cash then return end

    exports.qbx_core:SyncEconomyMoney(src, { bank = personal.balance, cash = cash.balance })
end

return mirror
