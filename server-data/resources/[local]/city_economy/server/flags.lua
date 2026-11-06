-- Suspicious activity is recorded, never just ignored: a silent refusal hides the cheater, a flag finds them
local flags = {}

---@param src integer? player source, if online
---@param citizenid string?
---@param kind string short tag, e.g. 'honeypot'
---@param severity integer 1 (odd) to 5 (certain cheat)
---@param context table?
function flags.add(src, citizenid, kind, severity, context)
    local license

    if src then
        local player = exports.qbx_core:GetPlayer(src)

        citizenid = citizenid or (player and player.PlayerData.citizenid)
        license = GetPlayerIdentifierByType(src --[[@as string]], 'license2') or GetPlayerIdentifierByType(src --[[@as string]], 'license')
    end

    lib.print.warn(('[flag %d] %s: source %s, citizenid %s, %s'):format(
        severity, kind, tostring(src), tostring(citizenid), context and json.encode(context) or '-'
    ))

    -- Never nil in the list: a nil would shift every value after it
    MySQL.insert(
        'INSERT INTO `economy_flags` (`citizenid`, `license`, `kind`, `severity`, `context`) VALUES (?, ?, ?, ?, ?)',
        { citizenid or '', license or '', kind, severity, context and json.encode(context) or '' }
    )
end

return flags
