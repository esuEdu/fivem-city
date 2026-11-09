-- What the mining shop sells and what each tool does. Shared so the client can draw the menus; the server prices,
-- checks and applies everything from this same file.
local gear = {}

gear.licence = { item = 'mining_license', price = 500, days = 7 }
gear.explosives = { item = 'explosives_license', price = 2000, days = 14, level = 16 }

-- Mining level that unlocks each vein tier
gear.tierLevels = { 1, 8, 16, 24 }

-- tier: the highest vein tier it breaks; speed: share of the base mining time
gear.pickaxes = {
    pickaxe = { tier = 1, level = 1, price = 250, durability = 120, speed = 1.0 },
    steel_pickaxe = { tier = 2, level = 8, price = 2500, durability = 250, speed = 0.9 },
    hardened_pickaxe = { tier = 3, level = 16, price = 9000, durability = 400, speed = 0.8 },
    diamond_pickaxe = { tier = 4, level = 24, price = 25000, durability = 600, speed = 0.7 },
}

gear.pan = { item = 'gold_pan', level = 1, price = 400, durability = 200 }
gear.sluice = { item = 'sluice_box', price = 8000, skill = 'golden_pan' }

-- Safety gear: carried in the inventory; the helmet is put on by using it
gear.ppe = {
    mining_helmet = { price = 1200 },
    mining_gloves = { price = 800 },
    mining_boots = { price = 1000 },
}

gear.furnace = { item = 'home_furnace', level = 10, price = 25000 }
gear.coal = { item = 'coal', price = 30 }
gear.dynamite = { item = 'dynamite', price = 600, perDay = 3 }

-- A full repair costs this share of the tool's price, less for a tool that is only partly worn
gear.repairShare = 0.4

---Every tool the shop sells, in menu order.
---@return { item: string, price: integer, level: integer, kind: string }[]
function gear.catalogue()
    local list = {}

    for name, data in pairs(gear.pickaxes) do
        list[#list + 1] = { item = name, price = data.price, level = data.level, kind = 'pickaxe', order = data.tier }
    end

    list[#list + 1] = { item = gear.pan.item, price = gear.pan.price, level = gear.pan.level, kind = 'pan', order = 10 }
    list[#list + 1] = { item = gear.sluice.item, price = gear.sluice.price, level = 1, kind = 'sluice', order = 11 }

    local order = 20
    for _, name in ipairs({ 'mining_helmet', 'mining_gloves', 'mining_boots' }) do
        list[#list + 1] = { item = name, price = gear.ppe[name].price, level = 1, kind = 'ppe', order = order }
        order = order + 1
    end

    list[#list + 1] = { item = gear.furnace.item, price = gear.furnace.price, level = gear.furnace.level, kind = 'furnace', order = 30 }

    table.sort(list, function(a, b) return a.order < b.order end)

    return list
end

---Max durability of a tool item, or nil for items that don't wear.
---@param name string
---@return integer?
function gear.durability(name)
    local pickaxe = gear.pickaxes[name]
    if pickaxe then return pickaxe.durability end
    if name == gear.pan.item then return gear.pan.durability end
end

---@param name string
---@return integer?
function gear.price(name)
    local pickaxe = gear.pickaxes[name]
    if pickaxe then return pickaxe.price end
    if name == gear.pan.item then return gear.pan.price end
end

return gear
