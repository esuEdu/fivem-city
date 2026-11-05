-- Notifications and badges per character, kept in memory (gone after a restart), newest first.

local notifications = {}

---@class Note
---@field id integer
---@field app string
---@field title string
---@field body string
---@field time integer os.time()
---@field banner boolean
---@field open? table passed to the app when the notification is tapped

---@type table<string, Note[]>
local byCitizen = {}

---@type table<string, table<string, integer>>
local badges = {}

local nextId = 0

---@param value unknown
---@param max integer
---@return string?
local function text(value, max)
    if type(value) ~= 'string' or #value == 0 then return end

    return #value > max and value:sub(1, max) or value
end

---Checks what a script sent; returns the note to store.
---@param data unknown
---@return Note?
---@return string? reason
function notifications.validate(data)
    if type(data) ~= 'table' then return nil, 'not a table' end

    local title = text(data.title, 80)
    if not title then return nil, 'title is required' end

    nextId = nextId + 1

    return {
        id = nextId,
        app = data.app,
        title = title,
        body = text(data.body, 200) or '',
        time = os.time(),
        banner = data.banner == true,
        open = type(data.open) == 'table' and data.open or nil,
    }
end

---@param citizenid string
---@param note Note
function notifications.add(citizenid, note)
    local list = byCitizen[citizenid] or {}
    byCitizen[citizenid] = list

    table.insert(list, 1, note)

    for i = #list, Config.MaxNotifications + 1, -1 do
        list[i] = nil
    end
end

---@param citizenid string
---@return Note[]
function notifications.list(citizenid)
    return byCitizen[citizenid] or {}
end

---@param citizenid string
function notifications.clear(citizenid)
    byCitizen[citizenid] = nil
end

---@param citizenid string
---@param app string
---@param count integer
function notifications.setBadge(citizenid, app, count)
    local list = badges[citizenid] or {}
    badges[citizenid] = list

    list[app] = count > 0 and count or nil
end

---@param citizenid string
---@return table<string, integer>
function notifications.badges(citizenid)
    return badges[citizenid] or {}
end

return notifications
