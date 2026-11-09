-- The police badge on screen (server/badge.lua decides who sees it). The officer showing it holds the badge up.

local theme = require '@city_ui.theme'

local ANIM_DICT = 'paper_1_rcm_alt1-9'
local ANIM = 'player_one_dual-9'

local function holdBadge()
    local ped = cache.ped
    lib.requestModel(Config.Badge.prop)
    lib.requestAnimDict(ANIM_DICT)

    local prop = CreateObject(Config.Badge.prop, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 28422), 0.065, 0.029, -0.035, 80.0, -1.9, 75.0, true, true, false, true, 1, true)
    TaskPlayAnim(ped, ANIM_DICT, ANIM, 8.0, -8.0, Config.Badge.seconds * 1000, 49, 0, false, false, false)

    SetModelAsNoLongerNeeded(Config.Badge.prop)
    RemoveAnimDict(ANIM_DICT)

    SetTimeout(Config.Badge.seconds * 1000, function()
        if DoesEntityExist(prop) then DeleteEntity(prop) end
        StopAnimTask(ped, ANIM_DICT, ANIM, 1.0)
    end)
end

RegisterNetEvent('city_police:client:showBadge', function(card)
    if GetInvokingResource() or type(card) ~= 'table' then return end

    if card.officer == cache.serverId then holdBadge() end

    SendNUIMessage({
        action = 'badge',
        theme = theme,
        card = card,
        seconds = Config.Badge.seconds,
        labels = { rank = locale('badge_rank'), callsign = locale('badge_callsign'), number = locale('badge_number') },
    })
end)
