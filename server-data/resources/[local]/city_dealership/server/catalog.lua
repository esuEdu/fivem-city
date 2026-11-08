-- What the dealership sells, built once from qbx_core's vehicle list and Config.Categories.
local catalog = {}

local byModel = {}
local list = {}
local sold = {}

for i = 1, #Config.Categories do
    sold[Config.Categories[i].id] = true
end

for model, vehicle in pairs(exports.qbx_core:GetVehiclesByName()) do
    local price = math.tointeger(vehicle.price)

    if sold[vehicle.category] and not Config.Blocklist[model] and price and price > 0 then
        local entry = {
            model = model,
            name = vehicle.name or model,
            brand = vehicle.brand or '',
            price = price,
            category = vehicle.category,
            image = Config.Images[model] or Config.ImageUrl:format(model),
        }

        byModel[model] = entry
        list[#list + 1] = entry
    end
end

table.sort(list, function(a, b) return a.price < b.price end)

---@param model any
---@return table?
function catalog.get(model)
    return type(model) == 'string' and byModel[model] or nil
end

---@return table[]
function catalog.list()
    return list
end

---@param entry table
---@return string
function catalog.label(entry)
    if entry.brand ~= '' then return ('%s %s'):format(entry.brand, entry.name) end

    return entry.name
end

-- The player stands at one of the dealership computers
---@param src integer
---@return boolean
function catalog.atComputer(src)
    local ped = GetPlayerPed(src)
    if ped <= 0 then return false end

    local coords = GetEntityCoords(ped)

    for i = 1, #Config.Computers do
        if #(coords - Config.Computers[i].coords) <= Config.UseDistance + 1.0 then return true end
    end

    return false
end

return catalog
