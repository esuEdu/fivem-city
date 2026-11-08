-- Billing tab, the CreateBill export for other jobs, the /bill test command and what happens when bills get paid
local access = require 'server.access'
local bills = require 'server.bills'
local money = require 'server.money'
local profile = require 'server.profile'
local rules = require 'server.rules'
local settings = require 'server.config'

local function fail(code) return { ok = false, error = code } end

local function payeesFor(kind)
    if kind == 'fine' then
        return {
            { system = 'GOV_TREASURY', pct = settings.fines.governmentPct },
            { job = settings.fines.policeJob, pct = 100 - settings.fines.governmentPct },
        }
    end

    return { { system = 'GOV_TREASURY', pct = 100 } }
end

access.panel('bills', function(_, _, citizenid)
    local rows = bills.list(citizenid)
    local out = {}

    for i = 1, #rows do
        local remaining, fee = bills.due(rows[i])

        out[i] = {
            id = rows[i].id, kind = rows[i].kind, label = rows[i].label, issuer = rows[i].issuer, amount = rows[i].amount,
            paid = rows[i].paid, remaining = remaining, fee = fee, minimum = math.max(0, rows[i].minimum - rows[i].paid),
            status = rows[i].status, due = rows[i].due_at, created = rows[i].created_at,
        }
    end

    local days = profile.overdue(citizenid)

    return { ok = true, bills = out, overdueDays = days, restrictions = profile.restrictions(citizenid) }
end)

---mode 'full' pays everything with the late fee; 'minimum' pays a card invoice's minimum
access.panel('payBill', function(_, _, citizenid, id, mode)
    id = access.int(id)

    local bill = id and MySQL.single.await(
        [[SELECT * FROM `bank_bills` WHERE `id` = ? AND `citizenid` = ? AND `status` IN ('pending', 'overdue')]],
        { id, citizenid }
    )

    if not bill then return fail('no_bill') end

    local remaining = bill.amount - bill.paid
    local amount = remaining

    if mode == 'minimum' then
        if bill.kind ~= 'card' or bill.status ~= 'pending' then return fail('bad_request') end
        amount = math.max(0, bill.minimum - bill.paid)
        if amount == 0 then return fail('minimum_paid') end
    elseif mode ~= 'full' then
        return fail('bad_request')
    end

    local personal = money.owned(citizenid, 'personal')
    local ok, err = bills.pay(bill, personal.id, amount, 'bank-bill')

    if not ok then return fail(err == 'insufficient funds' and 'insufficient' or 'failed') end

    return { ok = true }
end)

---Bill paid off: score, cashback on card invoices, and the debt freeze is lifted once nothing is overdue
AddEventHandler('city_bank:server:billPaid', function(bill)
    if bill.kind == 'card' then
        local tier = profile.tier(bill.citizenid)
        local wasOnTime = bill.status == 'pending'

        if wasOnTime then profile.addScore(bill.citizenid, 'invoicePaid') end

        local cashback = rules.pctCredit(bill.amount, tier.cashback)
        local personal = money.owned(bill.citizenid, 'personal')

        if cashback > 0 and personal then
            money.move(money.system('BANK_RESERVE'), personal.id, cashback, 'bank-cashback', bill.citizenid)
        end
    end

    local _, overdue = profile.overdue(bill.citizenid)
    local personal = money.owned(bill.citizenid, 'personal')

    if not overdue and personal and personal.frozen == 'debt' then
        exports.city_economy:BankSetFrozen(personal.id, false)
        money.notify(bill.citizenid, locale('notify_unfrozen'), 'success')
    end
end)

-- Retention: part of what reaches a debtor's personal account pays their overdue bills (BANCO_DESIGN.md 7)
local SKIP_RETENTION = { ['bank-retention'] = true, ['bank-move'] = true, ['bank-card-refund'] = true, ['bank-loan'] = true, ['bank-bill'] = true }

AddEventHandler('city_economy:server:credited', function(accountId, citizenid, amount, reason)
    if SKIP_RETENTION[reason] then return end

    local _, overdue = profile.overdue(citizenid)

    if overdue then bills.retain(accountId, citizenid, amount) end
end)

---Other resources (e.g. a rewritten police job) create bills here. Only resources in settings.billers may,
---and each one only its own kind of bill (paid into its own job account when the biller names one).
---@param targetSrc integer the player who owes
---@param amount integer
---@param label string
---@param issuerSrc integer? the player issuing it (an officer), must be next to the target
exports('CreateBill', function(targetSrc, amount, label, issuerSrc)
    local biller = settings.billers[GetInvokingResource()]
    local kind = type(biller) == 'table' and biller.kind or biller
    local target = type(targetSrc) == 'number' and exports.qbx_core:GetPlayer(targetSrc)

    if not kind or not target then return false end
    if math.type(amount) ~= 'integer' or amount <= 0 or amount > settings.bills.maxAmount then return false end
    if type(label) ~= 'string' then return false end

    local issuerName = GetInvokingResource()

    if issuerSrc then
        local issuer = exports.qbx_core:GetPlayer(issuerSrc)

        if not issuer or not access.near(issuerSrc, GetEntityCoords(GetPlayerPed(targetSrc)), 10.0) then return false end

        issuerName = access.name(issuer)
    end

    return bills.create({
        citizenid = target.PlayerData.citizenid, kind = kind, label = label, issuer = issuerName,
        amount = amount,
        payees = type(biller) == 'table' and biller.job and { { job = biller.job, pct = 100 } } or payeesFor(kind),
    }) ~= nil
end)

---Bill for a character who may be offline (installments a business schedules). Only resources in settings.billers.
---The issuer hears it was paid from the city_bank:server:billPaid event, matching the ref it gave.
---@param citizenid string
---@param amount integer
---@param label string
---@param dueSeconds integer how long until it is overdue
---@param ref string
---@return integer? billId
exports('IssueBill', function(citizenid, amount, label, dueSeconds, ref)
    local resource = GetInvokingResource()
    local biller = settings.billers[resource]
    local kind = type(biller) == 'table' and biller.kind or biller

    if not kind or type(citizenid) ~= 'string' or type(label) ~= 'string' or type(ref) ~= 'string' then return end
    if math.type(amount) ~= 'integer' or amount <= 0 or amount > settings.bills.maxAmount then return end
    if math.type(dueSeconds) ~= 'integer' or dueSeconds <= 0 then return end

    return bills.create({
        citizenid = citizenid, kind = kind, label = label, issuer = resource, amount = amount,
        due = os.time() + dueSeconds, ref = ref:sub(1, 32),
        payees = type(biller) == 'table' and biller.job and { { job = biller.job, pct = 100 } } or payeesFor(kind),
    })
end)

lib.addCommand('bill', {
    help = locale('command_bill'),
    params = {
        { name = 'id', type = 'playerId', help = locale('param_id') },
        { name = 'kind', type = 'string', help = 'fine | service' },
        { name = 'amount', type = 'number', help = locale('param_amount') },
        { name = 'label', type = 'longString', help = locale('param_label') },
    },
    restricted = 'group.admin',
}, function(source, args)
    -- source 0 = server console
    if source ~= 0 and not exports.qbx_core:IsOptin(source) then
        return exports.qbx_core:Notify(source, locale('not_on_duty'), 'error')
    end

    local target = exports.qbx_core:GetPlayer(args.id)
    local amount = math.tointeger(args.amount)
    local kind = args.kind == 'fine' and 'fine' or 'service'

    if not target or not amount or amount <= 0 or amount > settings.bills.maxAmount then
        if source ~= 0 then exports.qbx_core:Notify(source, locale('error_bad_amount'), 'error') end
        return
    end

    local actor = source == 0 and 'console' or access.name(exports.qbx_core:GetPlayer(source))

    bills.create({
        citizenid = target.PlayerData.citizenid, kind = kind, label = args.label or 'Bill', issuer = actor,
        amount = amount, payees = payeesFor(kind),
    })
    access.audit(actor, 'bill', target.PlayerData.citizenid, { kind = kind, amount = amount, label = args.label })

    if source ~= 0 then exports.qbx_core:Notify(source, locale('notify_bill_sent'), 'success') end
end)
