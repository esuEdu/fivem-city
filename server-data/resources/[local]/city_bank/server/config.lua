-- Server-only bank rules (BANCO_DESIGN.md 13). Not in files: players can't read limits, scores or fees.
local DAY = 86400

return {
    -- Ordered from lowest to highest. Limits are the default ceiling ("limite liberado") of each card.
    tiers = {
        { name = 'classic', label = 'Classic', minScore = 0, debitDay = 25000, creditLimit = 10000, atmDay = 10000, contactlessTx = 500, contactlessDay = 2000, fee = 0, cashback = 0, loanAuto = 25000, loanRate = 15, loanWeeks = 4 },
        { name = 'silver', label = 'Silver', minScore = 400, debitDay = 50000, creditLimit = 25000, atmDay = 20000, contactlessTx = 1000, contactlessDay = 4000, fee = 0, cashback = 0, loanAuto = 60000, loanRate = 12, loanWeeks = 6 },
        { name = 'gold', label = 'Gold', minScore = 550, debitDay = 100000, creditLimit = 60000, atmDay = 35000, contactlessTx = 2000, contactlessDay = 8000, fee = 500, cashback = 0.5, loanAuto = 150000, loanRate = 10, loanWeeks = 8 },
        { name = 'platinum', label = 'Platinum', minScore = 700, debitDay = 250000, creditLimit = 150000, atmDay = 50000, contactlessTx = 3000, contactlessDay = 12000, fee = 1500, cashback = 1, loanAuto = 300000, loanRate = 8, loanWeeks = 10 },
        { name = 'black', label = 'Black', minScore = 850, debitDay = 500000, creditLimit = 300000, atmDay = 75000, contactlessTx = 5000, contactlessDay = 20000, fee = 3000, cashback = 1.5, loanAuto = 600000, loanRate = 6, loanWeeks = 12 },
    },

    score = {
        start = 350,
        min = 0,
        max = 1000,
        weeklyGainCap = 40,
        invoicePaid = 10,
        installmentPaid = 5,
        loanRepaid = 25,
        cleanWeek = 5,
        minimumOnly = -5,
        overdue = -30,
        overduePerDay = -5,
        frozenForDebt = -100,
    },

    cards = {
        firstFee = 500,
        replaceFee = 1500,
        pinAttempts = 3,
        limitDelay = 60, -- seconds before a limit change applies
        maxCeilingMultiplier = 2, -- bankers may raise a ceiling up to this times the tier value
        maxPerAccount = 4, -- per holder and account
    },

    invoice = { cycle = 7 * DAY, dueAfter = 3 * DAY, minimumPct = 20, revolvingPct = 5 },

    bills = {
        dueAfter = 7 * DAY,
        lateFlatPct = 2,
        latePerDayPct = 0.5,
        lateMaxPct = 20,
        retentionPct = 30,
        -- Days overdue at which each restriction starts (BANCO_DESIGN.md 7)
        noNewCredit = 0,
        creditBlocked = 3,
        pixLimited = 7,
        freeze = 15,
        pixLimitedDay = 10000,
        maxAmount = 1000000,
    },

    fines = { governmentPct = 70, policeJob = 'police', policeCap = 500000, policeWindow = 30 * DAY },

    pix = {
        perTx = 200000,
        perDay = 500000,
        nightFrom = 22,
        nightTo = 6,
        nightLimit = 30000,
        newAccountSeconds = 10 * 3600,
        newAccountDay = 20000,
    },

    atm = { maxOperation = 50000, depositFlagOne = 50000, depositFlagDay = 150000, session = 120, maxDistance = 2.5 },

    teller = { maxOperation = 5000000 },

    pos = { mdrDebitPct = 2, mdrCreditPct = 3, maxCharge = 100000, expires = 60, maxDistance = 3.0 },

    -- The phone's Wallet app: the item it needs, and how long the card owner has to approve a purchase over the limit
    app = { item = 'phone', approvalSeconds = 60 },

    savings = { ratePct = 0.1, maxPerDay = 1000, every = DAY },

    shared = { maxPerPlayer = 1, memberDailyLimit = 20000 },

    jobs = { withdrawPerHour = 50000 },

    loans = { minAmount = 1000, maxActive = 1, every = 7 * DAY },

    scheduled = { daily = DAY, weekly = 7 * DAY, biweekly = 14 * DAY, maxPerPlayer = 10 },

    -- Server resources allowed to create bills with exports.city_bank:CreateBill: the bill kind, or { kind, job } to
    -- pay the whole bill into that job's account
    billers = {
        city_police = 'fine',
        city_hospital = { kind = 'service', job = 'ambulance' },
    },
}
