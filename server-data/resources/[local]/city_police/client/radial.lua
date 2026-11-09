-- The round action menu on this resource's screen page (web/screen.js): opened from ox_target on a player or a
-- vehicle, picked with the mouse. radial.choose waits for the pick and returns the item id (nil when closed).

local theme = require '@city_ui.theme'

local radial = {}

local pending = nil

---@param menu { title: string, subtitle: string?, items: { id: string, label: string, icon: string, disabled: boolean? }[] }
---@return string? id
function radial.choose(menu)
    if pending then return end
    if #menu.items == 0 then return end

    pending = promise.new()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'radial', theme = theme, menu = menu, labels = { close = locale('radial_close') } })

    local id = Citizen.Await(pending)
    pending = nil

    return id
end

---@param id string?
local function finish(id)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'radialOff' })

    if pending then pending:resolve(id) end
end

RegisterNUICallback('radialPick', function(data, cb)
    cb(1)
    finish(type(data) == 'table' and type(data.id) == 'string' and data.id or nil)
end)

RegisterNUICallback('radialClose', function(_, cb)
    cb(1)
    finish(nil)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not pending then return end

    SetNuiFocus(false, false)
end)

return radial
