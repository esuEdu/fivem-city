-- The hidden luck of the day: rolled when the resource starts and again when the server's date changes. Only the
-- server knows it; players notice it in their drops.
local settings = require 'server.config'

local luck = {}

local value = 0
local day

local function roll()
    day = os.date('%Y-%m-%d')
    value = settings.luck.min + math.random() * (settings.luck.max - settings.luck.min)
end

---@return number between luck.min and luck.max
function luck.get()
    if os.date('%Y-%m-%d') ~= day then roll() end

    return value
end

roll()

return luck
