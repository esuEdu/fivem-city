RegisterNetEvent('city_troll:client:launch', function(force)
    -- In a vehicle the whole car goes up; on foot the player ragdolls first so they tumble
    local entity = cache.vehicle or cache.ped

    if entity == cache.ped then
        SetPedToRagdoll(cache.ped, 5000, 5000, 0, false, false, false)
        Wait(0)
    end

    SetEntityVelocity(entity, 0.0, 0.0, force + 0.0)
end)
