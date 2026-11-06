-- Hospital fees: taken from the bank account; if there isn't enough, they become a bill (city_bank Billing tab)
local charges = {}

---@param src integer
---@param amount integer
---@param reason string 'hospital-...' (registered in city_economy's allowlist)
---@param label string what the bill says
function charges.take(src, amount, reason, label)
    if amount <= 0 then return end
    if exports.qbx_core:RemoveMoney(src, 'bank', amount, reason) then return end

    if GetResourceState('city_bank') == 'started' then
        exports.city_bank:CreateBill(src, amount, label)
    end
end

return charges
