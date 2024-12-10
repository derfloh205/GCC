local Object = require("GCC/Util/classics")
local TUtil = require("GCC/Util/tutil")
local f = string.format
--- GVector
---@class GVector
---@overload fun(x: number, y: number, z: number): GVector
local GVector = Object:extend()

function GVector:new(x, y, z)
    self.x = x
    self.y = y
    self.z = z
end

function GVector:__tostring()
    return f("(%d,%d,%d)", self.x, self.y, self.z)
end

---@param gvector GVector
---@return number
function GVector:EuclidDistance(gvector)
    return math.sqrt((self.x - gvector.x) ^ 2 + (self.y - gvector.y) ^ 2 + (self.z - gvector.z) ^ 2)
end

---@param gvector GVector
---@return number
function GVector:ManhattanDistance(gvector)
    return math.abs(self.x - gvector.x) + math.abs(self.y - gvector.y) + math.abs(self.z - gvector.z)
end

---@param gvector GVector
---@return boolean
function GVector:Equal(gvector)
    return self.x == gvector.x and self.y == gvector.y and self.z == gvector.z
end

---@param gvector GVector
---@return GVector
function GVector:Sub(gvector)
    return GVector(self.x - gvector.x, self.y - gvector.y, self.z - gvector.z)
end

---@param gvector GVector
---@return GVector
function GVector:Add(gvector)
    return GVector(self.x + gvector.x, self.y + gvector.y, self.z + gvector.z)
end

---@param number number
---@return GVector
function GVector:Mul(number)
    return GVector(self.x * number, self.y * number, self.z * number)
end

---@class GVector.Serialized
---@field x number
---@field y number
---@field z number

---@param serialized GVector.Serialized Serialized
---@return GVector
function GVector:Deserialize(serialized)
    return GVector(serialized.x, serialized.y, serialized.z)
end

---@return GVector.Serialized
function GVector:Serialize()
    return {
        x = self.x,
        y = self.y,
        z = self.z
    }
end

---@param serializedList GVector.Serialized[]
---@return GVector
function GVector:DeserializeList(serializedList)
    return TUtil:Map(
        serializedList,
        function(serialized)
            return self:Deserialize(serialized)
        end
    )
end

---@param list GVector[]
---@return GVector.Serialized[]
function GVector:SerializeList(list)
    return TUtil:Map(
        list,
        function(gVector)
            return gVector:Serialize()
        end
    )
end

return GVector
