local studio = require 'client.studio'
local look = require 'client.look'
local creator = require 'client.creator'
local theme = require '@city_ui.theme'
local qbxConfig = require '@qbx_core.config.client'
local defaultSpawn = require '@qbx_core.config.shared'.defaultSpawn
local nationalities = require '@qbx_core.data.nationalities'

local characters = {}
local skins = {}
local busy = false

local chars = qbxConfig.characters
local NATIONALITY = {}
for i = 1, #nationalities do NATIONALITY[nationalities[i]] = true end

local function fadeOut(ms)
    DoScreenFadeOut(ms)
    while not IsScreenFadedOut() do Wait(0) end
end

local function capitalize(str)
    return (str:gsub("(%a)([%a']*)", function(first, rest) return first:upper() .. rest:lower() end))
end

---Same rules the panel shows; the server's createCharacter checks types and lengths again
local function checkIdentity(identity)
    if type(identity) ~= 'table' then return nil, 'identity' end

    local function name(value)
        if type(value) ~= 'string' then return nil end
        value = value:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
        -- Bytes 128-255 let accented letters (UTF-8) through; 40 bytes fits 20 of them
        if #value < 2 or #value > 40 or not value:match("^[%a\128-\255][%a\128-\255 '%-]*$") then return nil end
        if chars.profanityWords[value:lower()] then return nil end
        for word in value:gmatch('%S+') do
            if chars.profanityWords[word:lower()] then return nil end
        end
        return capitalize(value)
    end

    local firstname, lastname = name(identity.firstname), name(identity.lastname)
    if not firstname then return nil, 'firstname' end
    if not lastname then return nil, 'lastname' end

    local birthdate = identity.birthdate
    if type(birthdate) ~= 'string' or not birthdate:match('^%d%d%d%d%-%d%d%-%d%d$')
        or birthdate < chars.dateMin or birthdate > chars.dateMax then
        return nil, 'birthdate'
    end

    local nationality = identity.nationality
    if type(nationality) ~= 'string' or (chars.limitNationalities and not NATIONALITY[nationality]) then
        return nil, 'nationality'
    end

    return { firstname = firstname, lastname = lastname, birthdate = birthdate, nationality = nationality }
end

local function spawnAt(coords)
    exports.spawnmanager:spawnPlayer({ x = coords.x, y = coords.y, z = coords.z, heading = coords.w })

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
end

local function leaveStudio()
    creator.close()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    studio.stop()
end

-- A brand-new character: the starting apartment (qbx_properties) or the default spawn
local function spawnNew(newData)
    fadeOut(300)
    leaveStudio()

    if chars.startingApartment and GetResourceState('qbx_properties') == 'started' then
        TriggerEvent('apartments:client:setupSpawnUI', newData)
    else
        spawnAt(defaultSpawn)
        DoScreenFadeIn(500)
    end
end

-- A character that already played: city_spawn's picker, or where they logged out
local function spawnExisting()
    fadeOut(300)
    leaveStudio()

    if GetResourceState('city_spawn') == 'started' then
        exports.city_spawn:Open()
    else
        spawnAt(exports.qbx_core:GetPlayerData().position)
        DoScreenFadeIn(500)
    end
end

local openSelect

local function previewCharacter(citizenid)
    local model, skin = nil, skins[citizenid]

    if citizenid and skin == nil then
        local data, hash = lib.callback.await('qbx_core:server:getPreviewPedData', false, citizenid)
        skin = data and { data = data, model = hash } or false
        skins[citizenid] = skin
    end

    if skin then model = skin.model end
    look.preview(model, skin and skin.data)
    studio.replacePed()
end

local function openCreator(options, finish)
    creator.open(options, finish, options.mode == 'new' and function()
        creator.close()
        openSelect()
    end or nil)
end

local function createNew()
    local newData

    openCreator({ mode = 'new', identity = { dateMin = chars.dateMin, dateMax = chars.dateMax } }, function(draft, rawIdentity)
        if busy then return false, 'busy' end

        local identity, err = checkIdentity(rawIdentity)
        if not identity then return false, err end

        busy = true

        -- A retry after the look failed to save must not make a second character
        if not newData then
            newData = lib.callback.await('qbx_core:server:createCharacter', false, {
                firstname = identity.firstname,
                lastname = identity.lastname,
                nationality = identity.nationality,
                birthdate = identity.birthdate,
                gender = draft.sex == 'f' and 1 or 0,
            })

            if not newData then
                busy = false
                return false, 'create'
            end
        end

        if not lib.callback.await('city_character:saveLook', false, draft) then
            busy = false
            return false, 'look'
        end

        busy = false
        CreateThread(function() spawnNew(newData) end)
        return true
    end)
end

local function play(citizenid, hasLook)
    if busy then return end
    busy = true

    lib.callback.await('qbx_core:server:loadCharacter', false, citizenid)
    busy = false

    if hasLook then
        spawnExisting()
        return
    end

    -- Made before the creator saved a look (left mid-way): build it now, sex fixed by the character
    local character = characters[citizenid]
    openCreator({ mode = 'look', sex = character and character.gender == 1 and 'f' or 'm' }, function(draft)
        if busy then return false, 'busy' end
        busy = true

        local ok = lib.callback.await('city_character:saveLook', false, draft)
        busy = false
        if not ok then return false, 'look' end

        CreateThread(spawnExisting)
        return true
    end)
end

local function characterList(list, looks)
    local out = {}
    characters = {}

    for i = 1, #list do
        local c = list[i]
        local info = c.charinfo or {}
        local entry = {
            citizenid = c.citizenid,
            firstname = info.firstname,
            lastname = info.lastname,
            gender = info.gender,
            birthdate = info.birthdate,
            nationality = info.nationality,
            phone = info.phone,
            job = c.job and c.job.label or 'Unemployed',
            grade = c.job and c.job.grade and c.job.grade.name or '',
            cash = c.money and c.money.cash or 0,
            bank = c.money and c.money.bank or 0,
            lastPlayed = c.lastLoggedOut,
            hasLook = looks[c.citizenid] == true,
        }

        characters[c.citizenid] = entry
        out[i] = entry
    end

    return out
end

function openSelect()
    local list, slots = lib.callback.await('qbx_core:server:getCharacters')
    local looks = lib.callback.await('city_character:looks') or {}
    local entries = characterList(list or {}, looks)

    studio.start()
    previewCharacter(entries[1] and entries[1].citizenid)

    SendNUIMessage({
        action = 'select',
        theme = theme,
        characters = entries,
        slots = slots,
        canDelete = chars.enableDeleteButton,
        nationalities = nationalities,
    })
    SetNuiFocus(true, true)
end

RegisterNUICallback('select:preview', function(data, cb)
    cb(true)
    if creator.isOpen() then return end

    local citizenid = type(data) == 'table' and data.citizenid
    previewCharacter(characters[citizenid] and citizenid or nil)
end)

RegisterNUICallback('select:play', function(data, cb)
    cb(true)
    local citizenid = type(data) == 'table' and data.citizenid
    local character = characters[citizenid]
    if not character or creator.isOpen() then return end

    play(citizenid, character.hasLook)
end)

RegisterNUICallback('select:create', function(_, cb)
    cb(true)
    if creator.isOpen() or busy then return end

    createNew()
end)

RegisterNUICallback('select:delete', function(data, cb)
    local citizenid = type(data) == 'table' and data.citizenid
    if not chars.enableDeleteButton or not characters[citizenid] or busy then return cb(false) end

    busy = true
    local ok = lib.callback.await('qbx_core:server:deleteCharacter', false, citizenid)
    busy = false
    skins[citizenid] = nil

    cb(ok == true)
    if ok then openSelect() end
end)

local function boot()
    exports.spawnmanager:setAutoSpawn(false)

    fadeOut(0)
    NetworkStartSoloTutorialSession()
    while not NetworkIsInTutorialSession() do Wait(0) end

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    openSelect()
    Wait(500)
    DoScreenFadeIn(800)
end

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end

    skins = {}
    CreateThread(boot)
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end

    -- Restarting this resource mid-game must not pull a playing character back to the select screen
    if LocalPlayer.state.isLoggedIn then return end

    boot()

    -- Nothing should hurt a player still choosing; invincibility alone is known to drop, so keep setting it
    while NetworkIsInTutorialSession() do
        SetEntityInvincible(cache.ped, true)
        Wait(250)
    end
    SetEntityInvincible(cache.ped, false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or not studio.isActive() then return end

    SetNuiFocus(false, false)
    studio.stop()
end)
