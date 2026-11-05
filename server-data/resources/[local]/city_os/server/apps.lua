-- Apps other resources register with exports.city_os:RegisterApp, and which of them each player may see.

local settings = require 'shared.settings'

local apps = {}

---@class AppAccess
---@field jobs? table<string, integer> job -> lowest grade
---@field gangs? table<string, integer> gang -> lowest grade
---@field staff? string ACE needed (with admin duty)
---@field unlock? string hidden until the player has this unlock

---@class App
---@field id string
---@field resource string
---@field label string
---@field page string
---@field icon { glyph: string, colors: string[], glyphColor: string, tint: string }
---@field access? AppAccess
---@field order number

---@type table<string, App>
local registry = {}

---@param value unknown
---@return boolean
local function isColor(value)
    return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
end

---@param groups unknown
---@return table<string, integer>?
local function toGroups(groups)
    if type(groups) ~= 'table' then return end

    local result = {}

    for name, grade in pairs(groups) do
        local level = math.tointeger(tonumber(grade))
        if type(name) == 'string' and level and level >= 0 then result[name] = level end
    end

    return next(result) and result or nil
end

---@param data unknown
---@return table? icon
local function toIcon(data)
    if type(data) ~= 'table' then return end

    -- SVG path data only (letters, digits, spaces, commas, dots, minus), drawn by the tablet as a stroke
    local glyph = data.glyph
    if type(glyph) ~= 'string' or #glyph > 2000 or not glyph:match('^[%w%s%.,%-]+$') then return end

    local colors = data.colors
    if type(colors) ~= 'table' or #colors ~= 3 then return end

    for i = 1, 3 do
        if not isColor(colors[i]) then return end
    end

    return {
        glyph = glyph,
        colors = { colors[1], colors[2], colors[3] },
        glyphColor = isColor(data.glyphColor) and data.glyphColor or '#ffffff',
        tint = isColor(data.tint) and data.tint or colors[1],
    }
end

---Checks a registration; returns the app, or nil and why not.
---@param resource string
---@param data unknown
---@return App?
---@return string? reason
function apps.validate(resource, data)
    if type(data) ~= 'table' then return nil, 'not a table' end
    if not settings.isAppId(data.id) then return nil, 'id must be letters, digits, _ or -, up to 32 characters' end
    if data.id == 'settings' then return nil, 'id "settings" is the tablet\'s own' end
    if type(data.label) ~= 'string' or #data.label == 0 or #data.label > 24 then return nil, 'label must be 1 to 24 characters' end

    local page = data.page
    if type(page) ~= 'string' or not page:match('^[%w_%-/%.]+%.html$') or page:find('..', 1, true) or page:sub(1, 1) == '/' then
        return nil, 'page must be an .html file inside the resource'
    end

    local icon = toIcon(data.icon)
    if not icon then return nil, 'icon needs glyph (SVG path data) and colors (three #rrggbb)' end

    local access

    if data.access ~= nil then
        if type(data.access) ~= 'table' then return nil, 'access must be a table' end

        access = {
            jobs = toGroups(data.access.jobs),
            gangs = toGroups(data.access.gangs),
            staff = type(data.access.staff) == 'string' and data.access.staff or nil,
            unlock = settings.isAppId(data.access.unlock) and data.access.unlock or nil,
        }

        if not (access.jobs or access.gangs or access.staff or access.unlock) then access = nil end
    end

    return {
        id = data.id,
        resource = resource,
        label = data.label,
        page = page,
        icon = icon,
        access = access,
        order = tonumber(data.order) or 100,
    }
end

---@param resource string
---@param data unknown
---@return boolean success
---@return string? reason
function apps.register(resource, data)
    local app, reason = apps.validate(resource, data)
    if not app then return false, reason end

    local existing = registry[app.id]
    if existing and existing.resource ~= resource then return false, ('id %s belongs to %s'):format(app.id, existing.resource) end

    registry[app.id] = app

    return true
end

---@param resource string
---@return boolean removed any
function apps.removeResource(resource)
    local removed = false

    for id, app in pairs(registry) do
        if app.resource == resource then
            registry[id] = nil
            removed = true
        end
    end

    return removed
end

---@param id string
---@return App?
function apps.get(id)
    return registry[id]
end

---@param groups? table<string, integer>
---@param group? { name: string, grade?: { level?: integer } }
---@return boolean
local function inGroup(groups, group)
    if not groups or not group then return false end

    local required = groups[group.name]

    return required ~= nil and ((group.grade and group.grade.level) or 0) >= required
end

---@class Viewer
---@field job? table qbx job (name, grade.level)
---@field gang? table qbx gang
---@field isStaff fun(ace: string): boolean has the ACE and is on admin duty
---@field unlocks table<string, true>

---Whether this player may see (and open) the app. Any one rule is enough.
---@param app App
---@param viewer Viewer
---@return boolean
function apps.canSee(app, viewer)
    local access = app.access
    if not access then return true end

    if access.jobs and inGroup(access.jobs, viewer.job) then return true end
    if access.gangs and inGroup(access.gangs, viewer.gang) then return true end
    if access.staff and viewer.isStaff(access.staff) then return true end
    if access.unlock and viewer.unlocks[access.unlock] then return true end

    return false
end

---The apps this player sees, as the tablet page needs them, in home screen order.
---@param viewer Viewer
---@return table[]
function apps.visible(viewer)
    local list = {}

    for _, app in pairs(registry) do
        if apps.canSee(app, viewer) then
            list[#list + 1] = {
                id = app.id,
                label = app.label,
                url = ('https://cfx-nui-%s/%s'):format(app.resource, app.page),
                resource = app.resource,
                icon = app.icon,
                -- Unlocked secret apps stay off the lock screen and notification previews
                hidden = app.access and app.access.unlock ~= nil or false,
                order = app.order,
            }
        end
    end

    table.sort(list, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.label < b.label
    end)

    return list
end

return apps
