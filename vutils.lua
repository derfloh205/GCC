---@class VUtils
local VUtils = {}

function VUtils:EuclidDistance(v1, v2)
    return math.sqrt((v1.x - v2.x) ^ 2 + (v1.y - v2.y) ^ 2 + (v1.z - v2.z) ^ 2)
end

function VUtils:ManhattanDistance(v1, v2)
    return math.abs(v1.x - v2.x) + math.abs(v1.y - v2.y) + math.abs(v1.z - v2.z)
end

function VUtils:Equal(v1, v2)
    return v1.x == v2.x and v1.y == v2.y and v1.z == v2.z
end

return VUtils
