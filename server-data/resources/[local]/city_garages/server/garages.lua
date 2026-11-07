-- Garage registry and the checks every server handler shares. Loaded with require by main.lua, spawn.lua and park.lua.

local settings = require 'server.config'

local VEHICLES = exports.qbx_core:GetVehiclesByName()
local KINDS = { car = true, air = true, sea = true }

local garages = {}

local M = {
    State = { OUT = 0, GARAGED = 1, IMPOUNDED = 2 },
}

---@param spawns any
---@return vector4[]?
local function cleanSpawns(spawns)
    if type(spawns) ~= 'table' or #spawns == 0 then return end

    local list = {}

    for i = 1, #spawns do
        if type(spawns[i]) ~= 'vector4' then return end
        list[i] = spawns[i]
    end

    return list
end

---@param id string
---@param data table
---@return table? garage
local function normalize(id, data)
    if type(id) ~= 'string' or id == '' or type(data) ~= 'table' then return end
    if type(data.label) ~= 'string' or not KINDS[data.kind] or type(data.coords) ~= 'vector4' then return end

    local spawns = cleanSpawns(data.spawns)
    if not spawns then return end

    local blip = data.blip
    if blip == nil then blip = Config.Blips[data.depot and 'depot' or data.kind] end

    return {
        id = id,
        label = data.label,
        kind = data.kind,
        depot = data.depot == true,
        groups = data.groups,
        coords = data.coords,
        spawns = spawns,
        blip = blip or false,
        ped = data.ped ~= false,
        -- a function from another resource arrives as a callable table (funcref)
        canAccess = (type(data.canAccess) == 'function' or type(data.canAccess) == 'table') and data.canAccess or nil,
    }
end

-- What clients get: everything but the server-side access check
---@param garage table
---@return table
function M.public(garage)
    return {
        id = garage.id,
        label = garage.label,
        kind = garage.kind,
        depot = garage.depot,
        groups = garage.groups,
        coords = garage.coords,
        spawns = garage.spawns,
        blip = garage.blip,
        ped = garage.ped,
    }
end

---@param id any
---@return table?
function M.get(id)
    return type(id) == 'string' and garages[id] or nil
end

---@return table<string, table>
function M.all()
    return garages
end

---@param id string
---@param data table
---@return table? garage
function M.register(id, data)
    local garage = normalize(id, data)

    if not garage then
        lib.print.warn(('city_garages: garage %s was not registered (bad label, kind, coords or spawns)'):format(id))
        return
    end

    garages[id] = garage

    return garage
end

-- The player may use this garage and stands next to it
---@param src integer
---@param garage table
---@return boolean
function M.canUse(src, garage)
    if garage.groups and not exports.qbx_core:HasPrimaryGroup(src, garage.groups) then return false end
    if garage.canAccess then
        local ok, allowed = pcall(garage.canAccess, src)
        if not ok or not allowed then return false end
    end

    local ped = GetPlayerPed(src)

    return ped > 0 and #(GetEntityCoords(ped) - garage.coords.xyz) <= Config.UseDistance + 1.0
end

---@param modelName string
---@return 'car'|'air'|'sea'?
function M.kindOf(modelName)
    local vehicle = VEHICLES[modelName]
    if not vehicle then return end

    return Config.TypeKinds[vehicle.type] or 'car'
end

---@param modelName string
---@return string
function M.label(modelName)
    local vehicle = VEHICLES[modelName]
    if not vehicle then return modelName end
    if vehicle.brand and vehicle.brand ~= '' then return ('%s %s'):format(vehicle.brand, vehicle.name) end

    return vehicle.name
end

---@param plate string
---@return string
function M.normalizePlate(plate)
    return plate:match('^%s*(.-)%s*$'):upper()
end

-- Plates of every vehicle in the world, so a car that is still out isn't handed out twice
---@return table<string, true>
function M.platesInWorld()
    local plates = {}
    local vehicles = GetAllVehicles()

    for i = 1, #vehicles do
        plates[M.normalizePlate(GetVehicleNumberPlateText(vehicles[i]))] = true
    end

    return plates
end

-- Impound lot fee: a price someone set on the car (exports.qbx_vehicles depotprice), else a share of its catalogue price
---@param playerVehicle table qbx_vehicles PlayerVehicle
---@return integer
function M.depotFee(playerVehicle)
    local set = math.tointeger(playerVehicle.depotPrice)
    if set and set > 0 then return set end

    local vehicle = VEHICLES[playerVehicle.modelName]
    local fee = math.floor((vehicle and vehicle.price or 0) * settings.depotFee.share + 0.5)

    return math.max(settings.depotFee.min, math.min(settings.depotFee.max, fee))
end

for id, data in pairs(Config.Garages) do
    M.register(id, data)
end

return M
