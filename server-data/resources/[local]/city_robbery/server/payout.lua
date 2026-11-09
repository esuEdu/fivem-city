local payout = {}

---ATM payout: the base plus perOfficer of the base for each officer on duty.
---@param base number
---@param perOfficer number
---@param officers integer
---@return integer
function payout.atm(base, perOfficer, officers)
    officers = math.max(0, math.floor(tonumber(officers) or 0))

    return math.floor(base * (1 + perOfficer * officers) + 0.5)
end

return payout
