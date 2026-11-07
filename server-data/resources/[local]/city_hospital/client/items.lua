-- Bandage, painkillers and IFAK on yourself. The server asks here when the item is used; it takes the item only if the
-- progress bar finished.
local painUntil = 0

local function painkillers(seconds)
    local wasOn = painUntil > GetGameTimer()

    painUntil = math.max(painUntil, GetGameTimer() + seconds * 1000)
    exports.qbx_medical:DisableDamageEffects()

    if wasOn then return end

    CreateThread(function()
        while GetGameTimer() < painUntil do Wait(1000) end
        exports.qbx_medical:EnableDamageEffects()
    end)
end

lib.callback.register('city_hospital:useItem', function(name)
    local item = Config.Items[name]
    if not item or LocalPlayer.state.isDead then return false end

    local anim = Config.Anims[item.anim]
    local done = lib.progressCircle({
        duration = item.time,
        position = 'bottom',
        label = locale(('progress_%s'):format(name)),
        canCancel = true,
        disable = { combat = true },
        anim = { dict = anim.dict, clip = anim.clip },
    })

    if not done then return false end

    if item.health then SetEntityHealth(cache.ped, math.min(GetEntityMaxHealth(cache.ped), GetEntityHealth(cache.ped) + item.health)) end
    if item.bleed then exports.qbx_medical:RemoveBleed(item.bleed) end
    if item.painSeconds then painkillers(item.painSeconds) end

    return true
end)
