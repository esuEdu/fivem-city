-- Payouts, kept off the client
return {
    atm = {
        base = 15000,
        -- Each officer on duty adds this share of the base (linear, no cap): 1 officer = $18,000, 5 = $30,000
        perOfficer = 0.20,
    },
    store = {
        amount = 200000,
    },
}
