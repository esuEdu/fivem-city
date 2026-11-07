-- What the phone's Wallet app may do: the same panel requests as the branch, with the same rules and limits
-- (BANCO_DESIGN.md 10). Everything else (cards issued, unlocking, loans, staff) stays at the branch.
local access = require 'server.access'

local APP = { 'accounts', 'history', 'lookup', 'send', 'cards', 'blockCard', 'cardLimits', 'cardContactless' }

for _, name in ipairs(APP) do
    access.allowApp(name)
end
