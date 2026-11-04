dofile('harness.lua')
Config.StashDistance = 5.0; Config.TrunkDistance = 4.0
Config.VehicleStorage = {
    trunk = { automobile = { slots = 30, maxWeight = 100000 } },
    glovebox = { automobile = { slots = 5, maxWeight = 10000 } },
    models = { [77] = { trunk = { slots = 80, maxWeight = 500000 } } },
}
local vdata = setmetatable({}, { __mode = 'k' })
local proto = newproxy(true)
local V = getmetatable(proto)
V.__index = function(u, k) return vdata[u][k] end
V.__sub = function(a, b) return vec3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
vec3 = function(x, y, z) local u = newproxy(proto) vdata[u] = { x = x, y = y, z = z } return u end
local realType = type
type = function(v) if realType(v) == 'userdata' and vdata[v] then return 'vector3' end return realType(v) end

local world = { ped = vec3(0, 0, 0), inside = 0 }
local cars = { [10] = { coords = vec3(2, 0, 0), plate = ' ABC123 ', model = 1, vtype = 'automobile', lock = 1 },
               [11] = { coords = vec3(2, 0, 0), plate = 'BIGVAN', model = 77, vtype = 'automobile', lock = 1 },
               [12] = { coords = vec3(2, 0, 0), plate = 'BIKE1', model = 2, vtype = 'bike', lock = 1 } }
NetworkGetEntityFromNetworkId = function(n) return cars[n] and n or 0 end
DoesEntityExist = function(e) return cars[e] ~= nil end
GetEntityType = function() return 2 end
GetPlayerPed = function() return 1 end
GetVehiclePedIsIn = function() return world.inside end
GetEntityCoords = function(e) if e == 1 then return world.ped end return cars[e].coords end
GetVehicleNumberPlateText = function(e) return cars[e].plate end
GetEntityModel = function(e) return cars[e].model end
GetVehicleType = function(e) return cars[e].vtype end
GetVehicleDoorLockStatus = function(e) return cars[e].lock end
Entity = function(e) return { state = { doorslockstate = cars[e].stateLock } } end
locale = function(k) return k end
local opened = {}
TriggerClientEvent = function(name, src, data) if name == 'city_inventory:client:openOther' then opened[#opened + 1] = data end end
GetInvokingResource = function() return 'test' end
AddEventHandler = function() end
exports = { qbx_core = { GetPlayer = function() return { PlayerData = { citizenid = 'CID', job = {}, gang = {} } } end } }
local owned = { ABC123 = true }
MySQL = { scalar = { await = function(_, p) return owned[p[1]] and 1 or nil end } }
promise = { new = function() return { resolve = function() end } end }
Citizen = { Await = function() end }
local db = {}
local realRequire = require
require = function(m)
    if m == 'server.storage' then return { load = function(k) return db[k] end, save = function(rows) for _, r in ipairs(rows) do db[r.owner] = r.entries end end } end
    return realRequire(m)
end

local vehicles = require 'server.vehicles'
local stashes = require 'server.stashes'

assert(select(2, vehicles.open(1, 99, 'trunk')) == 'no_vehicle')
assert(select(2, vehicles.open(1, 10, 'hood')) == 'no_stash')
assert(vehicles.open(1, 10, 'trunk'))
assert(opened[#opened].id == 'trunk:ABC123' and opened[#opened].slots == 30)
assert(vehicles.open(1, 11, 'trunk') and opened[#opened].slots == 80)        -- model override
assert(select(2, vehicles.open(1, 12, 'trunk')) == 'no_storage')              -- bikes have none
cars[10].stateLock = 2
assert(select(2, vehicles.open(1, 10, 'trunk')) == 'vehicle_locked')
cars[10].stateLock = nil
world.ped = vec3(10, 0, 0)
assert(select(2, vehicles.open(1, 10, 'trunk')) == 'too_far')
world.ped = vec3(0, 0, 0)
assert(select(2, vehicles.open(1, 10, 'glovebox')) == 'too_far')             -- not sitting in it
world.inside = 10
assert(vehicles.open(1, 10, 'glovebox') and opened[#opened].id == 'glovebox:ABC123' and opened[#opened].slots == 5)
assert(select(2, vehicles.open(1, 10, 'trunk')) == 'too_far')                -- trunk not from inside
world.inside = 0
-- owned trunk is saved, a stranger's isn't
local owned_trunk = stashes.get('trunk:ABC123'); assert(owned_trunk:add('water', 1))
local van = stashes.get('trunk:BIGVAN'); assert(van.temporary and van:add('water', 1))
stashes.close(1)
stashes.saveAll()
assert(db['stash:trunk:ABC123'] and not db['stash:trunk:BIGVAN'])
assert(stashes.get('trunk:BIGVAN') == van)                                   -- still in memory
print('all vehicle storage tests passed')
