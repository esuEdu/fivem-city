-- The creator's NUI callbacks: every change is previewed on the ped right away; the server only sees the final draft
local studio = require 'client.studio'
local look = require 'client.look'
local appearance = require 'shared.appearance'

local creator = {}

local open = false
local onFinish
local onCancel

local SHOTS = { face = true, torso = true, body = true, feet = true }

local function num(value, min, max)
    return type(value) == 'number' and value == value and value >= min and value <= max
end

local function int(value, min, max)
    return num(value, min, max) and math.floor(value) == value
end

local function facePointsLoop()
    CreateThread(function()
        local last = ''

        while open do
            local points = studio.facePoints()
            local encoded = points and json.encode(points) or ''

            if encoded ~= last then
                last = encoded
                SendNUIMessage({ action = 'facePoints', points = points })
            end

            Wait(points and 50 or 250)
        end
    end)
end

---Opens the creator. mode 'new' asks for identity at the end; mode 'look' only builds the look of a character that has none
---@param options { mode: 'new'|'look', sex: 'm'|'f'?, identity: table? }
---@param finish fun(draft: table, identity: table?): boolean, string?
---@param cancel fun()?
function creator.open(options, finish, cancel)
    onFinish, onCancel = finish, cancel
    open = true

    local draft = look.defaultDraft(options.sex or 'm')
    look.apply(draft)
    studio.replacePed()
    studio.setShot('body', true)

    RequestStreamedTextureDict('char_creator_portraits', false)

    SendNUIMessage({
        action = 'creator',
        mode = options.mode,
        lockSex = options.sex ~= nil,
        draft = draft,
        catalog = look.catalog(),
        parents = appearance.PARENTS,
        facePoints = Config.FacePoints,
        eyeColors = Config.EyeColors,
        identity = options.identity,
    })
    SetNuiFocus(true, true)

    facePointsLoop()
end

function creator.close()
    open = false
    SetStreamedTextureDictAsNoLongerNeeded('char_creator_portraits')
end

function creator.isOpen()
    return open
end

local function guard(cb)
    if not open then
        cb(false)
        return false
    end

    return true
end

-- A new sex (or undo across one) sends the whole draft: the model changes and every piece goes back on
RegisterNUICallback('creator:apply', function(data, cb)
    if not guard(cb) then return end
    if type(data) ~= 'table' or not appearance.MODELS[data.sex] then return cb(false) end

    local sexChanged = GetEntityModel(cache.ped) ~= joaat(appearance.MODELS[data.sex])
    look.apply(data)

    if sexChanged then
        studio.replacePed()
        studio.setShot(studio.shot(), true)
    end

    cb(look.catalog())
end)

RegisterNUICallback('creator:defaults', function(data, cb)
    if not guard(cb) then return end
    if type(data) ~= 'table' or not appearance.MODELS[data.sex] then return cb(false) end

    cb(look.defaultDraft(data.sex))
end)

RegisterNUICallback('creator:heritage', function(data, cb)
    if not guard(cb) then return end
    if type(data) ~= 'table' or not int(data.mother, 0, 45) or not int(data.father, 0, 45)
        or not int(data.skinMother, 0, 45) or not int(data.skinFather, 0, 45)
        or not num(data.shapeMix, 0, 1) or not num(data.skinMix, 0, 1) then
        return cb(false)
    end

    look.setHeritage(data)
    cb(true)
end)

RegisterNUICallback('creator:feature', function(data, cb)
    if not guard(cb) then return end
    if type(data) ~= 'table' or type(data.name) ~= 'string' or not num(data.value, -1, 1) then return cb(false) end

    look.setFeature(data.name, data.value)
    cb(true)
end)

RegisterNUICallback('creator:overlay', function(data, cb)
    if not guard(cb) then return end
    if type(data) ~= 'table' or type(data.name) ~= 'string' or type(data.entry) ~= 'table' then return cb(false) end

    local entry = data.entry
    if not int(entry.style, 0, 255) or not num(entry.opacity, 0, 1) or not int(entry.color, 0, 63) then return cb(false) end

    look.setOverlay(data.name, entry)
    cb(true)
end)

RegisterNUICallback('creator:hair', function(data, cb)
    if not guard(cb) then return end
    if type(data) ~= 'table' or not int(data.style, 0, 2000) or not int(data.texture, 0, 255)
        or not int(data.color, 0, 63) or not int(data.highlight, 0, 63) then
        return cb(false)
    end

    look.setHair(data)
    cb({ textures = look.textures('hair', 2, data.style) })
end)

RegisterNUICallback('creator:eyes', function(data, cb)
    if not guard(cb) then return end
    if type(data) ~= 'table' or not int(data.color, 0, Config.EyeColors - 1) then return cb(false) end

    look.setEyes(data.color)
    cb(true)
end)

RegisterNUICallback('creator:piece', function(data, cb)
    if not guard(cb) then return end
    if type(data) ~= 'table' or (data.kind ~= 'component' and data.kind ~= 'prop') or not int(data.id, 0, 11)
        or not int(data.drawable, -1, 2000) or not int(data.texture, 0, 255) then
        return cb(false)
    end

    if data.kind == 'component' then
        look.setComponent(data.id, math.max(data.drawable, 0), data.texture)
    else
        look.setProp(data.id, data.drawable, data.texture)
    end

    cb({ textures = look.textures(data.kind, data.id, data.drawable) })
end)

RegisterNUICallback('creator:shot', function(data, cb)
    if type(data) == 'table' and SHOTS[data.name] then studio.setShot(data.name) end
    cb(true)
end)

RegisterNUICallback('creator:zoom', function(data, cb)
    if type(data) == 'table' and num(data.delta, -1, 1) then studio.zoom(data.delta) end
    cb(true)
end)

RegisterNUICallback('creator:rotate', function(data, cb)
    if type(data) == 'table' and num(data.degrees, -90, 90) then studio.rotate(data.degrees) end
    cb(true)
end)

RegisterNUICallback('creator:lights', function(data, cb)
    if type(data) == 'table' and type(data.name) == 'string' then studio.setLights(data.name) end
    cb(true)
end)

RegisterNUICallback('creator:finish', function(data, cb)
    if not guard(cb) then return end
    if type(data) ~= 'table' or type(data.draft) ~= 'table' then return cb({ ok = false, error = 'draft' }) end

    local ok, err = onFinish(data.draft, data.identity)
    cb({ ok = ok, error = err })
end)

RegisterNUICallback('creator:cancel', function(_, cb)
    cb(true)
    if open and onCancel then onCancel() end
end)

return creator
