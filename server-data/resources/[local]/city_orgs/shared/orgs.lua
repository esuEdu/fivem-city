-- Config.Apps flattened to one entry per faction, for both sides and the unit tests.
local shared = {}

---@class Faction
---@field gang string qbx gang name
---@field app string key of Config.Apps
---@field label string
---@field color string
---@field icon table
---@field order number
---@field farmItems string[]
---@field vault vector4
---@field stash { slots: integer, maxWeight: integer }

---@return table<string, Faction> gang -> faction
function shared.factions()
    local list = {}

    for appId, app in pairs(Config.Apps) do
        for gang, faction in pairs(app.factions) do
            list[gang] = {
                gang = gang,
                app = appId,
                label = faction.label,
                color = app.color,
                icon = app.icon,
                order = app.order,
                farmItems = app.farmItems,
                vault = faction.vault,
                stash = faction.stash or Config.Stash,
            }
        end
    end

    return list
end

return shared
