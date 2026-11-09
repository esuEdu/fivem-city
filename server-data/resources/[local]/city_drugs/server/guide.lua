-- What the Gang app (city_gangs) shows its members: for each drug, where its raw material is, the lab and its recipes,
-- what it sells for and how much it draws the police. Plain tables only, so it crosses exports and NUI as JSON.
local settings = require 'server.config'
local rules = require 'server.rules'

local function point(coords)
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function itemLabel(name)
    local item = exports.city_inventory:Items(name)

    return item and item.label or name
end

---{ { label, count } } sorted by label
local function itemList(items)
    local list = {}

    for name, count in pairs(items) do list[#list + 1] = { label = itemLabel(name), count = count } end
    table.sort(list, function(a, b) return a.label < b.label end)

    return list
end

local function drugGuide(id, drug)
    local guide = {
        id = id,
        label = drug.label,
        level = drug.level,
        gangOnly = settings.gangOnly.labs == true,
        gather = {},
        corner = {},
        deals = {},
        risk = {
            pick = rules.risk(drug, 'pick'),
            lab = rules.risk(drug, 'lab'),
            sale = rules.risk(drug, 'sale'),
            perPoint = drug.perPoint,
            max = drug.max,
        },
    }

    for _, field in pairs(Config.Fields) do
        if field.drug == id then
            local inside = field.inside and Config.Labs[field.inside]

            guide.gather[#guide.gather + 1] = {
                label = field.label,
                item = itemLabel(field.item),
                coords = point(inside and inside.entrance or field.center),
                inside = inside and inside.label or nil,
            }
        end
    end

    local lab = Config.Labs[id]

    if lab then
        local recipes = {}

        for _, recipe in ipairs(lab.recipes) do
            recipes[#recipes + 1] = { label = recipe.label, inputs = itemList(recipe.inputs), outputs = itemList(recipe.outputs), seconds = recipe.seconds }
        end

        guide.lab = { label = lab.label, coords = point(lab.entrance), recipes = recipes }
    end

    for item, price in pairs(settings.corner.prices) do
        if price.drug == id then
            guide.corner[#guide.corner + 1] = { item = itemLabel(item), min = price.min, max = price.max, maxUnits = price.maxUnits }
        end
    end

    for _, order in ipairs(settings.deal.orders) do
        if order.drug == id then
            guide.deals[#guide.deals + 1] = { item = itemLabel(order.item), min = order.min, max = order.max, price = order.pricePerUnit }
        end
    end

    return guide
end

exports('Guide', function()
    local drugs = {}

    for id, drug in pairs(settings.drugs) do drugs[#drugs + 1] = drugGuide(id, drug) end
    table.sort(drugs, function(a, b) return settings.drugs[a.id].order < settings.drugs[b.id].order end)

    return {
        drugs = drugs,
        dealer = point(Config.Dealer.coords),
        dealMinutes = settings.deal.minutes,
        dealsGangOnly = settings.gangOnly.deals == true,
    }
end)
