--- Math Utils
---@class MUtil
local MUtil = {}

--- inclusive
---@param value number
---@param low number
---@param high number
function MUtil:InRange(value, low, high)
    return value <= high and value >= low
end

---@param value number
---@return number
function MUtil:Round(value)
    return math.floor(value + 0.5)
end

return MUtil
