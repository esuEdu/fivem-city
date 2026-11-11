-- The faction vault at each QG: an ox_target zone its members use to open the stash. The server checks the gang
-- and the distance again when the stash opens.
lib.locale()

local factions = require('shared.orgs').factions()

local zone

local function clearZone()
    if zone then
        exports.ox_target:removeZone(zone)
        zone = nil
    end
end

local function setup()
    clearZone()

    local playerData = exports.qbx_core:GetPlayerData()
    local gang = playerData and playerData.gang
    local faction = gang and factions[gang.name]
    if not faction then return end

    local vault = faction.vault

    zone = exports.ox_target:addBoxZone({
        coords = vec3(vault.x, vault.y, vault.z),
        size = vec3(1.6, 1.6, 2.0),
        rotation = vault.w,
        options = {
            {
                name = 'city_orgs:vault',
                icon = 'fa-solid fa-box-open',
                label = locale('open_vault'),
                distance = 2.0,
                onSelect = function()
                    exports.city_inventory:openInventory('stash', ('org:%s'):format(faction.gang))
                end,
            },
        },
    })
end

-- PlayerData catches up a moment after these events
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() SetTimeout(250, setup) end)
RegisterNetEvent('QBCore:Client:OnGangUpdate', function() SetTimeout(250, setup) end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then setup() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clearZone() end
end)
