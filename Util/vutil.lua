--- Vector Utils
---@class VUtil
local VUtil = {}

---@class Vector
---@field x number
---@field y number
---@field z number

---@param v1 Vector
---@param v2 Vector
---@return number
function VUtil:EuclidDistance(v1, v2)
    return math.sqrt((v1.x - v2.x) ^ 2 + (v1.y - v2.y) ^ 2 + (v1.z - v2.z) ^ 2)
end

---@param v1 Vector
---@param v2 Vector
---@return number
function VUtil:ManhattanDistance(v1, v2)
    return math.abs(v1.x - v2.x) + math.abs(v1.y - v2.y) + math.abs(v1.z - v2.z)
end

---@param v1 Vector
---@param v2 Vector
---@return boolean
function VUtil:Equal(v1, v2)
    return v1.x == v2.x and v1.y == v2.y and v1.z == v2.z
end

---@param v1 Vector
---@param v2 Vector
---@return Vector
function VUtil:Sub(v1, v2)
    return vector.new(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z)
end

---@param v1 Vector
---@param v2 Vector
---@return Vector
function VUtil:Add(v1, v2)
    return vector.new(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
end

---@param v Vector Serialized
---@return Vector
function VUtil:Deserialize(v)
    return vector.new(v.x, v.y, v.z)
end

return VUtil
