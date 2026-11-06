-- Shared state of the NUI page for client/main.lua, atm.lua and pos.lua (loaded with require, so it exists once)
local nui = {}

-- What the page is showing: nil, 'bank', 'atm' or 'pos'
nui.view = nil
-- Branch whose panel (or cash desk) is open
nui.branch = nil

---@param name 'bank' | 'atm' | 'pos'
---@param payload table
function nui.open(name, payload)
    nui.view = name
    TriggerScreenblurFadeIn(250)
    SetNuiFocus(true, true)
    payload.action = 'open'
    payload.view = name
    SendNUIMessage(payload)
end

function nui.close()
    if not nui.view then return end

    if nui.branch then lib.callback.await('city_bank:close', false) end
    if nui.view == 'atm' then lib.callback.await('city_bank:atmClose', false) end
    if nui.view == 'pos' and nui.charge then lib.callback.await('city_bank:posDecline', false, nui.charge) end

    nui.view, nui.branch, nui.charge = nil, nil, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerScreenblurFadeOut(250)
end

return nui
