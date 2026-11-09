-- Veins, gravel spots, super rocks and passage blockers near the player, from the GlobalState key of each region.
-- Rocks are local objects (never networked), created only within Config.SpawnDistance; the glow is drawn every frame
-- only while a vein is within Config.LightDistance.
local actions = require 'client.actions'

local spots = {}     -- key -> { point, coords, kind, tier, entity, data }
local near = {}      -- key -> true while within the spawn distance

---@param models table model hashes, the first one in the game's files is used
---@return integer?
local function pickModel(models)
    for _, model in ipairs(models) do
        if IsModelInCdimage(model) then return model end
    end
end

local function itemLabel(name)
    local item = exports.city_inventory:Items(name)
    return item and item.label or name
end

---@param spot table
---@return table[] ox_target options
local function optionsFor(spot)
    local data = spot.data

    if spot.kind == 'gravel' then
        return { { name = 'city_mining:pan', icon = 'fa-solid fa-water', label = locale('target_pan'), onSelect = function() actions.pan(data.id) end } }
    elseif spot.kind == 'super' then
        return { { name = 'city_mining:super', icon = 'fa-solid fa-bomb', label = locale('target_super'), onSelect = function() actions.dynamite('super', spot.region) end } }
    elseif spot.kind == 'passage' then
        return { { name = 'city_mining:passage', icon = 'fa-solid fa-bomb', label = locale('target_passage'), onSelect = function() actions.dynamite('passage', spot.region) end } }
    end

    return { {
        name = 'city_mining:mine',
        icon = 'fa-solid fa-hammer',
        label = locale('target_mine', itemLabel(data.ore), data.tier),
        onSelect = function() actions.mine(data.id) end,
    } }
end

---@param spot table
local function create(spot)
    if spot.entity or spot.kind == 'gravel' then return end

    local models = spot.kind == 'super' and Config.SuperRockModel or spot.kind == 'passage' and Config.PassageModel or Config.Tiers[spot.tier].models
    local model = pickModel(models)
    if not model then return end

    lib.requestModel(model)
    local c = spot.coords
    local entity = CreateObject(model, c.x, c.y, c.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityHeading(entity, spot.heading or 0.0)
    PlaceObjectOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)
    exports.ox_target:addLocalEntity(entity, optionsFor(spot))

    spot.entity = entity
end

---@param spot table
local function destroy(spot)
    if spot.entity and DoesEntityExist(spot.entity) then
        exports.ox_target:removeLocalEntity(spot.entity)
        DeleteEntity(spot.entity)
    end

    spot.entity = nil
end

---@param key string
local function remove(key)
    local spot = spots[key]
    if not spot then return end

    destroy(spot)
    if spot.zone then exports.ox_target:removeZone(spot.zone) end
    if spot.point then spot.point:remove() end
    spots[key] = nil
    near[key] = nil
end

local watching = false

-- While any spot is in spawn range: every half second find the ones within the light distance, and only while
-- there are some draw their glow every frame
local function watchLights()
    if watching then return end
    watching = true

    CreateThread(function()
        while next(near) do
            local origin = GetEntityCoords(cache.ped)
            local lit = {}

            for key in pairs(near) do
                local spot = spots[key]
                if spot and #(origin - spot.coords) <= Config.LightDistance then lit[#lit + 1] = spot end
            end

            if #lit == 0 then
                Wait(500)
            else
                local untilAt = GetGameTimer() + 500

                while GetGameTimer() < untilAt do
                    for _, spot in ipairs(lit) do
                        local colour = spot.kind == 'gravel' and Config.GravelMarker or spot.tier and Config.Tiers[spot.tier].light
                        if colour then
                            local c = spot.coords
                            DrawLightWithRange(c.x, c.y, c.z + 1.0, colour[1], colour[2], colour[3], 2.5, 1.2)
                        end
                    end

                    Wait(0)
                end
            end
        end

        watching = false
    end)
end

---@param key string
---@param spot table
local function add(key, spot)
    spots[key] = spot

    -- Gravel has no rock: an ox_target sphere on the water
    if spot.kind == 'gravel' then
        spot.zone = exports.ox_target:addSphereZone({ coords = spot.coords, radius = 2.0, options = optionsFor(spot) })
    end

    spot.point = lib.points.new({
        coords = spot.coords,
        distance = Config.SpawnDistance,
        onEnter = function()
            create(spot)
            near[key] = true
            watchLights()
        end,
        onExit = function()
            destroy(spot)
            near[key] = nil
        end,
    })
end

---Brings the spots of one region in line with its state.
---@param region string
---@param state table?
local function sync(region, state)
    local wanted = {}

    if state then
        for _, vein in ipairs(state.veins or {}) do
            local key = ('%s:%d'):format(vein.kind, vein.id)
            wanted[key] = { kind = vein.kind, coords = vec3(vein.x, vein.y, vein.z), heading = vein.h, tier = vein.tier, data = vein, region = region }
        end

        if state.super then
            local s = state.super
            wanted[('super:%s'):format(region)] = { kind = 'super', coords = vec3(s.x, s.y, s.z), heading = s.h, data = s, region = region }
        end

        local passage = state.passage
        if passage and not passage.open then
            wanted[('passage:%s'):format(region)] = { kind = 'passage', coords = vec3(passage.x, passage.y, passage.z), heading = passage.h, data = passage, region = region }
        end
    end

    for key, spot in pairs(spots) do
        if spot.region == region and not wanted[key] then remove(key) end
    end

    for key, spot in pairs(wanted) do
        if not spots[key] then add(key, spot) end
    end
end

AddStateBagChangeHandler('', 'global', function(_, key, value)
    local region = key:match('^mining:(.+)$')
    if region then sync(region, value) end
end)

CreateThread(function()
    for _, region in ipairs(Config.Regions) do
        sync(region.id, GlobalState[('mining:%s'):format(region.id)])
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for key in pairs(spots) do remove(key) end
end)
