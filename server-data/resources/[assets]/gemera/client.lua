-- /gemeracheck: why the model doesn't spawn, from this player's game (temporary, for testing the add-on)
RegisterCommand('gemeracheck', function()
    local model = `gemera`
    local inImage = IsModelInCdimage(model)
    local isVehicle = IsModelAVehicle(model)

    local loaded = false
    if inImage then
        RequestModel(model)
        local timeout = GetGameTimer() + 10000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(100) end
        loaded = HasModelLoaded(model)
        SetModelAsNoLongerNeeded(model)
    end

    local result = ('gemeracheck: in game files %s, is a vehicle %s, model loaded %s'):format(inImage, isVehicle, loaded)
    print(result)
    TriggerEvent('chat:addMessage', { args = { 'gemera', result } })
end, false)
