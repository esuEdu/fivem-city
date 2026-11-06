dofile('harness.lua')

local rules = require 'server.rules'
local settings = require 'server.config'

-- Tiers follow the score thresholds
check(rules.tierFor(settings.tiers, 0).name == 'classic', 'score 0 is classic')
check(rules.tierFor(settings.tiers, 350).name == 'classic', 'starting score is classic')
check(rules.tierFor(settings.tiers, 400).name == 'silver', 'score 400 is silver')
check(rules.tierFor(settings.tiers, 849).name == 'platinum', 'score 849 is platinum')
check(rules.tierFor(settings.tiers, 1000).name == 'black', 'score 1000 is black')

-- Rounding always favours the bank
check(rules.pctDebit(101, 2) == 3, 'fee on 101 at 2% rounds up to 3')
check(rules.pctCredit(101, 2) == 2, 'yield on 101 at 2% rounds down to 2')

-- Late fee: 2% + 0.5% per day, never above 20%
check(rules.lateFee(1000, 0, settings.bills) == 0, 'no fee before the due date')
check(rules.lateFee(1000, 1, settings.bills) == 25, 'one day late is 2.5%')
check(rules.lateFee(1000, 100, settings.bills) == 200, 'late fee is capped at 20%')

-- Splits always add up to the total
local parts = rules.split(1001, { 70, 30 })
check(parts[1] + parts[2] == 1001, 'split keeps the total')
check(parts[2] == 300, 'police share is rounded down')

-- Loan plan: the installments add up to the total
local total, installment, last = rules.loanPlan(10000, 15, 4)
check(total == 11500, 'loan total includes interest')
check(installment * 3 + last == total, 'installments add up to the total')
local total2, installment2, last2 = rules.loanPlan(1001, 12, 6)
check(installment2 * 5 + last2 == total2 and last2 > 0, 'uneven loan still adds up')

-- Limits stay between 0 and the ceiling, and must be whole numbers
local ceilings = { debitDay = 1000, atmDay = 500 }
local limits = rules.clampLimits({ debitDay = 5000, atmDay = -10 }, ceilings)
check(limits.debitDay == 1000 and limits.atmDay == 0, 'limits are clamped to the ceiling')
check(rules.clampLimits({ debitDay = 10.5, atmDay = 1 }, ceilings) == nil, 'fractional limit is refused')
check(rules.clampLimits({ debitDay = '100', atmDay = 1 }, ceilings) == nil, 'string limit is refused')
check(rules.clampLimits({ debitDay = 100 }, ceilings) == nil, 'missing limit is refused')

-- Night window wraps past midnight
check(rules.inWindow(23, 22, 6), '23h is night')
check(rules.inWindow(3, 22, 6), '3h is night')
check(not rules.inWindow(12, 22, 6), 'noon is day')

check(rules.maskName('John', 'Doe') == 'J*** D**', 'names are masked')

check(rules.validPin('1234'), 'four digits is a PIN')
check(not rules.validPin('123'), 'three digits is not a PIN')
check(not rules.validPin(1234), 'number is not a PIN')
check(not rules.validPin('12a4'), 'letters are not a PIN')

-- Score: weekly gain cap, losses uncapped, clamped to 0..1000
local score, gain = rules.applyScore(500, 30, 0, settings.score)
check(score == 530 and gain == 30, 'gain is applied')
score, gain = rules.applyScore(score, 30, gain, settings.score)
check(score == 540 and gain == 40, 'gain stops at the weekly cap')
score = rules.applyScore(score, -100, gain, settings.score)
check(score == 440, 'loss is not capped')
check(rules.applyScore(10, -100, 0, settings.score) == 0, 'score never goes below 0')

finish()
