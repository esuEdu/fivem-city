lib.locale()

-- Items the labs and pick spots use must exist, or a batch would take inputs and give nothing
CreateThread(function()
    local settings = require 'server.config'
    local missing = {}
    local names = { settings.payItem }

    for _, field in pairs(Config.Fields) do names[#names + 1] = field.item end
    for _, item in ipairs(Config.CornerItems) do names[#names + 1] = item end
    for _, order in ipairs(settings.deal.orders) do names[#names + 1] = order.item end

    for _, lab in pairs(Config.Labs) do
        for _, recipe in ipairs(lab.recipes) do
            for item in pairs(recipe.inputs) do names[#names + 1] = item end
            for item in pairs(recipe.outputs) do names[#names + 1] = item end
        end
    end

    for _, name in ipairs(names) do
        if not exports.city_inventory:Items(name) then missing[#missing + 1] = name end
    end

    if #missing > 0 then
        lib.print.error(('city_drugs: unknown items in config: %s'):format(table.concat(missing, ', ')))
    end
end)
