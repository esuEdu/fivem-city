-- Everything the fishing shop sells, with the level it needs and its effects. Both sides read it: the client to draw the
-- shop menu, the server to price, check and apply it.
local gear = {}

gear.licence = { item = 'fishing_license', price = 250, days = 7 }

-- slots = tackle slots; durability = casts until it breaks
gear.rods = {
    fishing_rod_starter = { level = 1, price = 150, bait = false, slots = 0, durability = 150 },
    fishing_rod_fiberglass = { level = 5, price = 1200, bait = true, slots = 0, durability = 300 },
    fishing_rod_carbon = { level = 12, price = 6000, bait = true, slots = 1, durability = 500 },
    fishing_rod_pro = { level = 22, price = 20000, bait = true, slots = 2, durability = 800 },
}

-- Rod repair: dollars per durability point
gear.repairPerPoint = 2

-- wait: share of the bite wait taken off; bar: extra bar size; treasure: extra chest chance;
-- double: chance of two fish; challenge: perfect = 3 fish, 3 escapes lose it
gear.baits = {
    bait_worm = { level = 5, price = 5, wait = 0.5 },
    bait_deluxe = { level = 9, price = 40, wait = 0.67, bar = 12 },
    bait_magnet = { level = 16, price = 250, wait = 0.5, treasure = 0.15 },
    bait_wild = { level = 14, price = 80, wait = 0.625, double = 0.25 },
    bait_challenge = { level = 25, price = 150, wait = 0.625, challenge = true },
}

-- Tackle goes on rods with slots and lasts `uses` bites (junk doesn't wear it)
gear.tackleUses = 20

gear.tackle = {
    tackle_spinner = { level = 12, price = 500, waitSeconds = 3.75 },
    tackle_trap = { level = 12, price = 500, trap = true },
    tackle_lead = { level = 12, price = 500, lead = true },
    tackle_sonar = { level = 12, price = 500, sonar = true },
    tackle_cork = { level = 15, price = 750, bar = 24 },
    tackle_treasure = { level = 15, price = 750, treasure = 0.05 },
    tackle_barbed = { level = 18, price = 1000, barbed = true },
    tackle_quality = { level = 20, price = 1500, quality = 1 },
    tackle_curiosity = { level = 24, price = 2500, curiosity = true },
}

gear.pot = { item = 'crab_pot', level = 3, price = 400 }

---Combined effects of the tackle on a rod (two of the same stack, as in the research).
---@param tackle { name: string, uses: integer }[]?
---@return table
function gear.tackleEffects(tackle)
    local effects = { waitSeconds = 0, bar = 0, treasure = 0, quality = 0, trap = 0, lead = 0, barbed = 0 }

    for _, piece in ipairs(tackle or {}) do
        local data = gear.tackle[piece.name]

        if data then
            effects.waitSeconds = effects.waitSeconds + (data.waitSeconds or 0)
            effects.bar = effects.bar + (data.bar or 0)
            effects.treasure = effects.treasure + (data.treasure or 0)
            effects.quality = effects.quality + (data.quality or 0)
            if data.trap then effects.trap = effects.trap + 1 end
            if data.lead then effects.lead = effects.lead + 1 end
            if data.barbed then effects.barbed = effects.barbed + 1 end
            if data.sonar then effects.sonar = true end
            if data.curiosity then effects.curiosity = true end
        end
    end

    return effects
end

---Every item the shop lists, in menu order, with its price and level.
---@return { item: string, price: integer, level: integer, kind: string }[]
function gear.catalogue()
    local list = {}

    local function add(kind, items)
        local sorted = {}
        for name, data in pairs(items) do sorted[#sorted + 1] = { item = name, price = data.price, level = data.level, kind = kind } end
        table.sort(sorted, function(a, b) return a.level < b.level or (a.level == b.level and a.item < b.item) end)
        for i = 1, #sorted do list[#list + 1] = sorted[i] end
    end

    add('rod', gear.rods)
    add('bait', gear.baits)
    add('tackle', gear.tackle)
    list[#list + 1] = { item = gear.pot.item, price = gear.pot.price, level = gear.pot.level, kind = 'pot' }

    return list
end

return gear
