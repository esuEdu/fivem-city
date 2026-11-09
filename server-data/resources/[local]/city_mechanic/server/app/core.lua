-- The Mechanic app's server side: its city_os registration and the wrapper every app callback goes through. Written
-- for one job (Config.Job), so EMS and gang apps can start from a copy of server/app/.

local core = {}

local function registerApp()
    exports.city_os:RegisterApp({
        id = Config.App.id,
        label = Config.App.label,
        page = 'web/app/index.html',
        icon = Config.App.icon,
        access = { jobs = { [Config.Job] = 0 } },
        order = Config.App.order,
    })
end

registerApp()

-- city_os forgets its apps when it restarts
AddEventHandler('onResourceStart', function(resource)
    if resource == 'city_os' then registerApp() end
end)

---The player if they have the job (on duty or not).
---@param src integer
---@return table? player
function core.member(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job

    if job and job.name == Config.Job then return player end
end

---@param player table
---@return string
function core.fullName(player)
    local info = player.PlayerData.charinfo

    return ('%s %s'):format(info.firstname, info.lastname)
end

---Registers lib.callback 'city_mechanic:app:<name>' for members of the job; `boss` limits it to grades with isboss.
---The handler returns ok, then the result or why not.
---@param name string
---@param handler fun(src: integer, player: table, data: table): boolean, any
---@param options? { boss: boolean? }
function core.register(name, handler, options)
    local boss = options and options.boss

    lib.callback.register(('city_mechanic:app:%s'):format(name), function(source, data)
        local src = source
        local player = core.member(src)

        if not player then
            lib.print.warn(('city_mechanic: %s asked the app for %s without the job'):format(src, name))
            return false, 'no_permission'
        end

        if boss and not player.PlayerData.job.isboss then
            lib.print.warn(('city_mechanic: %s (%s) tried %s without being the boss'):format(GetPlayerName(src), src, name))
            return false, 'no_permission'
        end

        return handler(src, player, type(data) == 'table' and data or {})
    end)
end

---A citizenid from the page: letters and digits only.
---@param value unknown
---@return string?
function core.citizenid(value)
    if type(value) ~= 'string' or #value < 3 or #value > 50 or value:find('[^%w]') then return end

    return value
end

---Online job members (server ids), and whether each is on duty.
---@return table<integer, boolean>
function core.onlineMembers()
    local list = {}

    for src, player in pairs(exports.qbx_core:GetQBPlayers()) do
        local job = player.PlayerData.job
        if job and job.name == Config.Job then list[src] = job.onduty == true end
    end

    return list
end

---Open calls of the app's city_dispatch service.
---@return integer
function core.openCalls()
    if GetResourceState('city_dispatch') ~= 'started' then return 0 end

    return exports.city_dispatch:OpenCount(Config.App.service) or 0
end

---@type table<integer, integer> src -> badge last sent, so unchanged badges aren't sent again
local badges = {}

---@param src integer
---@param count integer
function core.setBadge(src, count)
    if badges[src] == count then return end

    badges[src] = count
    exports.city_os:SetBadge(src, Config.App.id, count)
end

-- Badge on the app icon: the open calls for members on duty, nothing for the others
function core.updateBadges()
    local count = core.openCalls()

    for src, duty in pairs(core.onlineMembers()) do
        core.setBadge(src, duty and count or 0)
    end
end

AddEventHandler('playerDropped', function()
    badges[source] = nil
end)

-- Badges belong to the character: a newly loaded one starts with nothing sent
AddEventHandler('QBCore:Server:OnPlayerLoaded', function()
    badges[source] = nil
end)

return core
