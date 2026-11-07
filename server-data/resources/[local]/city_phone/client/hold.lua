-- The phone in the player's hand while it is open: a prop on the right hand and the reading animation (sitting in a
-- car uses the car version).
local hold = {}

local prop
local holding = false

local function animFor()
    return cache.vehicle and Config.Anims.car or Config.Anims.foot
end

local function attachProp()
    local model = Config.Prop.model
    lib.requestModel(model)

    local coords = GetEntityCoords(cache.ped)
    prop = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(model)

    local offset, rotation = Config.Prop.offset, Config.Prop.rotation
    AttachEntityToEntity(prop, cache.ped, GetPedBoneIndex(cache.ped, Config.Prop.bone), offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z, true, true, false, true, 1, true)
end

function hold.start()
    if holding then return end

    holding = true
    attachProp()

    CreateThread(function()
        while holding do
            local anim = animFor()

            if not IsEntityPlayingAnim(cache.ped, anim.dict, anim.clip, 3) then
                lib.requestAnimDict(anim.dict)
                TaskPlayAnim(cache.ped, anim.dict, anim.clip, 3.0, 3.0, -1, 50, 0, false, false, false)
                RemoveAnimDict(anim.dict)
            end

            Wait(500)
        end
    end)
end

function hold.stop()
    if not holding then return end

    holding = false

    local anim = animFor()
    StopAnimTask(cache.ped, anim.dict, anim.clip, 2.0)

    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop = nil
end

return hold
