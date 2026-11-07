-- Ratings players give the staff member who closed their report. Only a rating the server asked for is taken: one per
-- report, from the player who sent it, within Config.RatingMinutes.

local rules = require 'shared.rules'

local ratings = {}

---@type table<integer, { citizenid: string, untilTime: integer }> closed reports waiting for the reporter's rating
local awaitingRating = {}

---@param reportId integer
---@param citizenid string the player who sent the report
function ratings.ask(reportId, citizenid)
    awaitingRating[reportId] = { citizenid = citizenid, untilTime = os.time() + Config.RatingMinutes * 60 }
end

lib.callback.register('city_staff:rateReport', function(source, data)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player or type(data) ~= 'table' then return false end

    local id = rules.toId(data.id)
    local waiting = id and awaitingRating[id]

    if not waiting or waiting.citizenid ~= player.PlayerData.citizenid or os.time() > waiting.untilTime then
        lib.print.warn(('city_staff: %s (%s) tried to rate report %s without being asked'):format(GetPlayerName(src), src, tostring(data.id)))
        return false
    end

    local rating = rules.rating(data.stars, data.tags, data.comment)
    if not rating then return false end

    awaitingRating[id] = nil
    MySQL.update('UPDATE `city_staff_reports` SET `rating` = ?, `rating_tags` = ?, `rating_comment` = ?, `rated_at` = ? WHERE `id` = ? AND `rating` IS NULL', {
        rating.stars, rating.tags, rating.comment, os.time(), id,
    })

    return true
end)

-- Unanswered rating requests are dropped once they expire
CreateThread(function()
    while true do
        Wait(60000)

        local now = os.time()

        for id, waiting in pairs(awaitingRating) do
            if now > waiting.untilTime then awaitingRating[id] = nil end
        end
    end
end)

return ratings
