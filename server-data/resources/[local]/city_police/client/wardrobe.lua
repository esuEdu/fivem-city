-- The station wardrobe (ox_target at Config.Stations[].wardrobe): a panel on the screen page with the uniforms for
-- this character's body, changing back to their own clothes (and clocking out), and for the chief, designing a new
-- uniform in illenium-appearance's clothing editor. Clothes are only changed on this ped, never saved as the skin.

local job = require 'client.job'
local theme = require '@city_ui.theme'

local appearance = exports['illenium-appearance']

local open = false
local zones = {}

---@return 'male' | 'female'
local function mySex()
    return GetEntityModel(cache.ped) == `mp_f_freemode_01` and 'female' or 'male'
end

-- Only clothes: mask, arms, legs, bag, shoes, accessories, undershirt, armour, decals, jacket and the hat. The face,
-- hair, glasses, ears, watch and bracelets are never read or changed (server/outfit.lua keeps the same list).
local COMPONENT_IDS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local HAT = 0

---What the ped wears now, read straight from the game, in illenium-appearance's format.
---@return { components: table[], props: table[] }
local function currentClothes()
    local ped = cache.ped
    local components = {}

    for _, id in ipairs(COMPONENT_IDS) do
        components[#components + 1] = { component_id = id, drawable = GetPedDrawableVariation(ped, id), texture = GetPedTextureVariation(ped, id) }
    end

    return { components = components, props = { { prop_id = HAT, drawable = GetPedPropIndex(ped, HAT), texture = GetPedPropTextureIndex(ped, HAT) } } }
end

---Puts on a uniform or the officer's own clothes. A uniform without a hat takes the hat off.
---@param clothes { components: table[], props: table[] }?
local function dress(clothes)
    if not clothes then return end

    local ped = cache.ped
    local hat = nil

    for _, entry in ipairs(clothes.components or {}) do
        SetPedComponentVariation(ped, entry.component_id, entry.drawable, math.max(entry.texture, 0), 0)
    end

    for _, entry in ipairs(clothes.props or {}) do
        if entry.prop_id == HAT then hat = entry end
    end

    if hat and hat.drawable >= 0 then
        SetPedPropIndex(ped, HAT, hat.drawable, math.max(hat.texture, 0), true)
    else
        ClearPedProp(ped, HAT)
    end
end

local function close()
    if not open then return end

    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'wardrobeOff' })
end

local function show()
    local data = lib.callback.await('city_police:wardrobe:list', false)
    if not data then return job.fail('too_far') end

    local sex = mySex()
    local list = {}

    for _, uniform in ipairs(data.uniforms) do
        if uniform.sex == sex then
            list[#list + 1] = { id = uniform.id, label = uniform.label, fixed = uniform.fixed == true, by = uniform.by }
        end
    end

    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'wardrobe',
        theme = theme,
        uniforms = list,
        canManage = data.canManage,
        wearing = data.wearing,
        onDuty = data.onDuty,
        labels = {
            title = locale('wardrobe_title'), subtitle = locale('wardrobe_subtitle'), uniforms = locale('wardrobe_uniforms'),
            mine = locale('wardrobe_mine'), wear = locale('wardrobe_wear'), back = locale('wardrobe_back'),
            backOff = locale('wardrobe_back_off'), new = locale('wardrobe_new'), none = locale('wardrobe_none'),
            notWearing = locale('wardrobe_not_wearing'), by = locale('wardrobe_by'), close = locale('radial_close'),
            sure = locale('wardrobe_sure'), mineHint = locale('wardrobe_mine_hint'),
        },
    })
end

-- The chief dresses a new uniform in the clothing editor, then names it
local function design()
    close()

    local ok, reason = lib.callback.await('city_police:wardrobe:startDesign', false, currentClothes())
    if not ok then return job.fail(reason) end

    appearance:startPlayerCustomization(function(result)
        if not result then return show() end

        local input = lib.inputDialog(locale('wardrobe_new'), {
            { type = 'input', label = locale('wardrobe_name'), required = true, min = 2, max = 40 },
        })

        if input and input[1] then
            -- What the ped wears now is what was confirmed in the editor
            local clothes = currentClothes()
            local created, why = lib.callback.await('city_police:wardrobe:create', false, {
                label = input[1], sex = mySex(), components = clothes.components, props = clothes.props,
            })

            if created then exports.qbx_core:Notify(locale('wardrobe_saved', input[1]), 'success') else job.fail(why) end
        end

        show()
    end, {
        ped = false, headBlend = false, faceFeatures = false, headOverlays = false, tattoos = false,
        components = true, props = true, enableExit = true,
        componentConfig = { masks = true, upperBody = true, lowerBody = true, bags = true, shoes = true, scarfAndChains = true, bodyArmor = true, shirts = true, decals = true, jackets = true },
        propConfig = { hats = true, glasses = false, ear = false, watches = false, bracelets = false },
    })
end

RegisterNUICallback('wardrobeClose', function(_, cb)
    cb(1)
    close()
end)

RegisterNUICallback('wardrobeWear', function(data, cb)
    cb(1)
    local id = type(data) == 'table' and data.id
    if type(id) == 'number' then id = math.tointeger(id) end
    if type(id) ~= 'string' and math.type(id) ~= 'integer' then return end

    local ok, clothes = lib.callback.await('city_police:wardrobe:wear', false, id, currentClothes())
    if not ok then return job.fail(clothes) end

    dress(clothes)
    show()
end)

RegisterNUICallback('wardrobeBack', function(data, cb)
    cb(1)
    local offDuty = type(data) == 'table' and data.offDuty == true

    local ok, clothes = lib.callback.await('city_police:wardrobe:changeBack', false, offDuty)
    if not ok then return job.fail(clothes) end

    dress(clothes)
    if offDuty then exports.qbx_core:Notify(locale('duty_off'), 'inform') end
    close()
end)

RegisterNUICallback('wardrobeNew', function(_, cb)
    cb(1)
    design()
end)

RegisterNUICallback('wardrobeDelete', function(data, cb)
    cb(1)
    local id = type(data) == 'table' and math.tointeger(data.id)
    if not id then return end

    local ok, reason = lib.callback.await('city_police:wardrobe:delete', false, id)
    if not ok then return job.fail(reason) end

    show()
end)

for _, station in ipairs(Config.Stations) do
    if station.wardrobe then
        zones[#zones + 1] = exports.ox_target:addSphereZone({
            coords = station.wardrobe,
            radius = 1.5,
            options = { {
                name = 'city_police:wardrobe', label = locale('target_wardrobe'), icon = 'fas fa-shirt',
                canInteract = job.isCop, onSelect = show,
            } },
        })
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    close()
    for _, id in ipairs(zones) do exports.ox_target:removeZone(id) end
end)
