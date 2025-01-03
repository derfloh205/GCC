local Object = require("GCC/Util/classics")
local GVector = require("GCC/GNav/gvector")
local TUtil = require("GCC/Util/tutil")
local MUtil = require("GCC/Util/mutil")
local CONST = require("GCC/Util/const")
local f = string.format

---@class GNAV.Boundary.Range
---@field min number
---@field max number

---@class GNAV
local GNAV = {}

---@class GNAV.Boundary : Object
---@overload fun() : GNAV.Boundary
GNAV.Boundary = Object:extend()

function GNAV.Boundary:new()
    ---@type  GNAV.Boundary.Range
    self.x = {}
    ---@type  GNAV.Boundary.Range
    self.y = {}
    ---@type  GNAV.Boundary.Range
    self.z = {}
end

---@param gridNode GNAV.GridNode
function GNAV.Boundary:Update(gridNode)
    self.x = {min = self.x.min or gridNode.pos.x, max = self.x.max or gridNode.pos.x}
    self.y = {min = self.y.min or gridNode.pos.y, max = self.y.max or gridNode.pos.y}
    self.z = {min = self.z.min or gridNode.pos.z, max = self.z.max or gridNode.pos.z}

    self.x.min = math.min(self.x.min, gridNode.pos.x)
    self.y.min = math.min(self.y.min, gridNode.pos.y)
    self.z.min = math.min(self.z.min, gridNode.pos.z)

    self.x.max = math.max(self.x.max, gridNode.pos.x)
    self.y.max = math.max(self.y.max, gridNode.pos.y)
    self.z.max = math.max(self.z.max, gridNode.pos.z)
end

---@param gnList GNAV.GridNode[]
function GNAV.Boundary:UpdateFromList(gnList)
    for _, gn in ipairs(gnList) do
        self:Update(gn)
    end
end

---@param gVector GVector
function GNAV.Boundary:UpdateFromGVector(gVector)
    self.x = {min = self.x.min or gVector.x, max = self.x.max or gVector.x}
    self.y = {min = self.y.min or gVector.y, max = self.y.max or gVector.y}
    self.z = {min = self.z.min or gVector.z, max = self.z.max or gVector.z}

    self.x.min = math.min(self.x.min, gVector.x)
    self.y.min = math.min(self.y.min, gVector.y)
    self.z.min = math.min(self.z.min, gVector.z)

    self.x.max = math.max(self.x.max, gVector.x)
    self.y.max = math.max(self.y.max, gVector.y)
    self.z.max = math.max(self.z.max, gVector.z)
end

function GNAV.Boundary:UpdateFromGVectorList(gvList)
    for _, gv in ipairs(gvList) do
        self:UpdateFromGVector(gv)
    end
end

---@param gVector GVector
function GNAV.Boundary:IsWithin(gVector)
    local inX = MUtil:InRange(gVector.x, self.x.min, self.x.max)
    local inY = MUtil:InRange(gVector.y, self.y.min, self.y.max)
    local inZ = MUtil:InRange(gVector.z, self.z.min, self.z.max)
    return inX and inY and inZ
end

---@return number sizeX
---@return number sizeY
---@return number sizeZ
function GNAV.Boundary:GetSize()
    local sizeX = self.x.max - self.x.min
    local sizeY = self.y.max - self.y.min
    local sizeZ = self.z.max - self.z.min
    return sizeX, sizeY, sizeZ
end

---@class GNAV.Boundary.Serialized
---@field x GNAV.Boundary.Range
---@field y GNAV.Boundary.Range
---@field z GNAV.Boundary.Range

---@return GNAV.Boundary.Serialized
function GNAV.Boundary:Serialize()
    return {
        x = {min = self.x.min, max = self.x.max},
        y = {min = self.y.min, max = self.y.max},
        z = {min = self.z.min, max = self.z.max}
    }
end

---@param serialized GNAV.Boundary.Serialized
---@return GNAV.Boundary
function GNAV.Boundary:Deserialize(serialized)
    local boundary = GNAV.Boundary
    boundary.x = {min = serialized.x.min, max = serialized.x.max}
    boundary.y = {min = serialized.y.min, max = serialized.y.max}
    boundary.z = {min = serialized.z.min, max = serialized.z.max}
    return boundary
end

--- Possible Look Directions
---@enum GNAV.HEAD
GNAV.HEAD = {
    N = "N", -- North
    S = "S", -- South
    W = "W", -- West
    E = "E" -- East
}

--- Possible Relative Directions
---@enum GNAV.DIR
GNAV.DIR = {
    F = "F", -- Forward
    B = "B", -- Back
    U = "U", -- Up
    D = "D" -- Down
}

-- Relative Heading by Vector Diff between adjacent positions
GNAV.DIFF_HEAD = {
    [0] = {
        [0] = {
            [-1] = GNAV.DIR.U,
            [1] = GNAV.DIR.D
        },
        [-1] = {[0] = GNAV.HEAD.S},
        [1] = {[0] = GNAV.HEAD.N}
    },
    [1] = {
        [0] = {
            [0] = GNAV.HEAD.W
        }
    },
    [-1] = {
        [0] = {
            [0] = GNAV.HEAD.E
        }
    }
}

-- Absolute Vector Diffs based on Heading
GNAV.HEAD_DIFF = {
    [GNAV.HEAD.N] = GVector(0, 1, 0),
    [GNAV.HEAD.S] = GVector(0, 1, 0),
    [GNAV.HEAD.W] = GVector(1, 0, 0),
    [GNAV.HEAD.E] = GVector(1, 0, 0),
    [GNAV.DIR.U] = GVector(0, 0, 1),
    [GNAV.DIR.D] = GVector(0, 0, 1)
}

---@class GNAV.GridNode.Options
---@field gridMap GNAV.GridMap
---@field pos GVector
---@field blockData table?
---@field unknown? boolean

---@class GNAV.GridNode : Object
---@overload fun(options: GNAV.GridNode.Options) : GNAV.GridNode
GNAV.GridNode = Object:extend()

---@param options GNAV.GridNode.Options
function GNAV.GridNode:new(options)
    options = options or {}
    self.gridMap = options.gridMap
    self.pos = options.pos
    self:SetBlockData(options.blockData)
    self.unknown = options.unknown or false
    self.visited = false
end

function GNAV.GridNode:SetBlockData(blockData)
    ---@type BlockData?
    self.blockData = blockData
    self.unknown = false
end

function GNAV.GridNode:IsVisited()
    return self.visited
end

function GNAV.GridNode:SetEmpty()
    self:SetBlockData(nil)
end

---@return boolean isChest
function GNAV.GridNode:IsChest()
    return self:IsItemOf(CONST.CHEST_BLOCKS)
end

---@param blockName string
---@return boolean isItem
function GNAV.GridNode:IsItem(blockName)
    if self:IsEmpty() or self:IsUnknown() then
        return false
    end
    return self.blockData.name == blockName
end

---@param itemList string[]
---@return boolean isItemOf
function GNAV.GridNode:IsItemOf(itemList)
    if self:IsEmpty() or self:IsUnknown() then
        return false
    end
    return TUtil:tContains(itemList, self.blockData.name)
end

---@return boolean isEmpty
function GNAV.GridNode:IsEmpty()
    return self.blockData == nil
end

---@return boolean isUnknown
function GNAV.GridNode:IsUnknown()
    return self.unknown
end

--- Using ManhattanDistance
---@param gridNode GNAV.GridNode
---@return number distance
function GNAV.GridNode:GetDistance(gridNode)
    return self.pos:ManhattanDistance(gridNode.pos)
end

---@param gridNode GNAV.GridNode
---@return boolean equalPos
function GNAV.GridNode:EqualPos(gridNode)
    return self.pos:Equal(gridNode.pos)
end

---@param gridNode GNAV.GridNode
---@return GNAV.HEAD
function GNAV.GridNode:GetRelativeHeading(gridNode)
    local vecDiff = self.pos:Sub(gridNode.pos)

    return GNAV.DIFF_HEAD[vecDiff.x][vecDiff.y][vecDiff.z]
end

--- get relative pos by given heading and direction to look at
---@param head GNAV.HEAD
---@param dir GNAV.DIR
function GNAV.GridNode:GetRelativeNode(head, dir)
    -- use the z diff vector if dir is up or down else use the x/y vector
    local relVec = GNAV.HEAD_DIFF[dir] or GNAV.HEAD_DIFF[head]

    -- possible movement directions that cause coordination subtraction
    if
        dir == GNAV.DIR.D or (head == GNAV.HEAD.W and dir == GNAV.DIR.F) or (head == GNAV.HEAD.E and dir == GNAV.DIR.B) or
            (head == GNAV.HEAD.N and dir == GNAV.DIR.F) or
            (head == GNAV.HEAD.S and dir == GNAV.DIR.B)
     then
        relVec = relVec:Mul(-1)
    end

    return self.gridMap:GetGridNode(self.pos:Add(relVec))
end

function GNAV.GridNode:__tostring()
    local typeChar = self:GetDrawString()
    return f("%s[%s] ", tostring(self.pos), typeChar)
end

function GNAV.GridNode:GetDrawString()
    local mapFunc = self.gridMap.gridNodeMapFunc

    local c = ""
    if self:IsUnknown() then
        c = " ? "
    elseif self:IsEmpty() then
        c = "   "
    else
        c = " X "
    end

    if mapFunc then
        c = mapFunc(self) or c
    end

    return c
end

---@param gridNode GNAV.GridNode
---@param flat? boolean
function GNAV.GridNode:GetClosestNeighbor(gridNode, flat)
    local neighbors = self.gridMap:GetNeighborsOf(self, flat)
    local closest = nil
    local minDist = math.huge

    for _, neighbor in ipairs(neighbors) do
        local dist = neighbor:GetDistance(gridNode)
        if dist < minDist then
            minDist = dist
            closest = neighbor
        end
    end

    return closest
end

---@class GNAV.GridNode.Serialized
---@field unknown boolean
---@field blockData BlockData?
---@field pos GVector.Serialized
---@field visited boolean

---@return GNAV.GridNode.Serialized
function GNAV.GridNode:Serialize()
    return {
        unknown = self.unknown,
        blockData = self.blockData,
        pos = self.pos:Serialize(),
        visited = self.visited
    }
end

---@param serializedGN GNAV.GridNode.Serialized
---@param gridMap GNAV.GridMap
---@return GNAV.GridNode
function GNAV.GridNode:Deserialize(serializedGN, gridMap)
    local gridNode =
        GNAV.GridNode {
        gridMap = gridMap,
        pos = GVector:Deserialize(serializedGN.pos),
        blockData = serializedGN.blockData,
        unknown = serializedGN.unknown
    }
    gridNode.visited = serializedGN.visited
    return gridNode
end

---@alias GNAV.GridMap.Grid table<number, table<number, table<number, GNAV.GridNode>>>
---@alias GNAV.GridMap.Grid.Serialized table<number, table<number, table<number, GNAV.GridNode.Serialized>>>

---@class GNAV.GridMap.Options

---@class GNAV.GridMap : Object
---@overload fun(options: GNAV.GridMap.Options) : GNAV.GridMap
GNAV.GridMap = Object:extend()

---@param options GNAV.GridMap.Options
function GNAV.GridMap:new(options)
    options = options or {}
    self.boundary = GNAV.Boundary()
    ---@type GNAV.GridMap.Grid
    self.grid = {}
    ---@type fun(gridNode: GNAV.GridNode): string?
    self.gridNodeMapFunc = nil
end

---@param func fun(gridNode: GNAV.GridNode): string?
function GNAV.GridMap:SetGNMapFunction(func)
    self.gridNodeMapFunc = func
end

---@param serializedGridMap table
function GNAV.GridMap:MergeSerializedGrid(serializedGridMap)
    for x, xData in pairs(serializedGridMap.grid) do
        for y, yData in pairs(xData) do
            for z, serializedGN in pairs(yData) do
                local gridNode = self:GetGridNode(GVector(x, y, z))
                gridNode.unknown = serializedGN.unknown
                gridNode.blockData = serializedGN.blockData
            end
        end
    end
end

---@return GNAV.GridMap.Grid.Serialized
function GNAV.GridMap:SerializeGrid()
    local serializedGrid = {}
    for x, xData in pairs(self.grid) do
        serializedGrid[x] = {}
        for y, yData in pairs(xData) do
            serializedGrid[x][y] = {}
            for z, gridNode in pairs(yData) do
                serializedGrid[x][y][z] = gridNode:Serialize()
            end
        end
    end
    return serializedGrid
end

---@param serializedGrid GNAV.GridMap.Grid.Serialized
---@return GNAV.GridMap.Grid
function GNAV.GridMap:DeserializeGrid(serializedGrid)
    local grid = {}
    for x, xData in pairs(serializedGrid) do
        grid[x] = {}
        for y, yData in pairs(xData) do
            grid[x][y] = {}
            for z, serializedGN in pairs(yData) do
                grid[x][y][z] = GNAV.GridNode:Deserialize(serializedGN, self)
            end
        end
    end
    return grid
end

---@class GNAV.GridMap.Serialized
---@field boundary GNAV.Boundary.Serialized
---@field grid GNAV.GridMap.Grid.Serialized

---@return GNAV.GridMap.Serialized
function GNAV.GridMap:Serialize()
    return {
        boundary = self.boundary:Serialize(),
        grid = self:SerializeGrid()
    }
end

---@return GNAV.GridMap
function GNAV.GridMap:Deserialize(serializedGridMap)
    local gridMap = GNAV.GridMap {}
    self.boundary = GNAV.Boundary:Deserialize(serializedGridMap.boundary)
    self.grid = self:DeserializeGrid(serializedGridMap.grid)
    return gridMap
end

function GNAV.GridMap:WriteFile()
    if not self.saveFile then
        return
    end
    local serializedGridMap = textutils.serialiseJSON(self)
    local saveFile = fs.open(self.saveFile, "w")
    saveFile.write(serializedGridMap)
    saveFile.close()
end

-- creates a new gridnode at pos or returns an existing one
---@param pos GVector
---@return GNAV.GridNode
function GNAV.GridMap:GetGridNode(pos)
    local x, y, z = pos.x, pos.y, pos.z
    self.grid[x] = self.grid[x] or {}
    self.grid[x][y] = self.grid[x][y] or {}
    local gridNode = self.grid[x][y][z]
    if not gridNode then
        gridNode =
            GNAV.GridNode(
            {
                gridMap = self,
                pos = pos
            }
        )
        gridNode.unknown = true
        self.grid[x][y][z] = gridNode
    end
    self.boundary:Update(gridNode)
    return gridNode
end

---@param gridNode GNAV.GridNode
---@param blockRadius number
---@param height number? default: 0
---@return GNAV.GridArea area
function GNAV.GridMap:GetAreaAround(gridNode, blockRadius, height)
    height = height or 0
    local areaNodes = {}

    for x = gridNode.pos.x - blockRadius, gridNode.pos.x + blockRadius do
        for y = gridNode.pos.y - blockRadius, gridNode.pos.y + blockRadius do
            for z = gridNode.pos.z, gridNode.pos.z + height do
                table.insert(areaNodes, self:GetGridNode(GVector(x, y, z)))
            end
        end
    end

    return GNAV.GridArea {nodeList = areaNodes, gridMap = self}
end

---@return number x
---@return number y
---@return number z
function GNAV.GridMap:GetGridSize()
    return self.boundary:GetSize()
end

---@param z number
---@param boundary GNAV.Boundary
---@return string gridString
function GNAV.GridMap:GetGridStringByBoundary(z, boundary)
    local minX = boundary.x.min
    local minY = boundary.y.min
    local maxX = boundary.x.max
    local maxY = boundary.y.max
    local gridString = ""

    for y = minY, maxY do
        for x = minX, maxX do
            local gridNode = self:GetGridNode(GVector(x, y, z))
            local c = gridNode:GetDrawString()

            if x == minX then
                c = "|" .. c
            end
            if x == maxX then
                c = c .. "|"
            end
            gridString = gridString .. c
        end
        gridString = gridString .. "\n"
    end
    return gridString
end

---@param z number
---@return string
function GNAV.GridMap:GetFullGridString(z)
    return self:GetGridStringByBoundary(z, self.boundary)
end

---@param centerPos GVector
---@param sizeX number
---@param sizeY? number
---@return string gridString
function GNAV.GridMap:GetCenteredGridString(centerPos, sizeX, sizeY)
    sizeY = sizeY or sizeX
    local centeredBoundary = GNAV.Boundary()
    centeredBoundary.x = {
        min = centerPos.x - math.floor(sizeX / 2),
        max = centerPos.x + math.ceil(sizeX / 2)
    }
    centeredBoundary.y = {
        min = centerPos.y - math.floor(sizeY / 2),
        max = centerPos.y + math.ceil(sizeY / 2)
    }
    return self:GetGridStringByBoundary(centerPos.z, centeredBoundary)
end

function GNAV.GridMap:IncreaseGridSize(incX, incY, incZ)
    for x = self.boundary.x.min - incX, self.boundary.x.max + incX do
        if not MUtil:InRange(x, self.boundary.x.min, self.boundary.x.max) then
            for y = self.boundary.y.min - incY, self.boundary.y.max + incY do
                if not MUtil:InRange(y, self.boundary.y.min, self.boundary.y.max) then
                    for z = self.boundary.z.min - incZ, self.boundary.z.max + incZ do
                        if not MUtil:InRange(z, self.boundary.z.min, self.boundary.z.max) then
                            self:GetGridNode(GVector(x, y, z))
                        end
                    end
                end
            end
        end
    end
end

---@param gridNode GNAV.GridNode
---@param flat? boolean
---@param filterFunc? fun(gridNode: GNAV.GridNode) : boolean
function GNAV.GridMap:GetNeighborsOf(gridNode, flat, filterFunc)
    ---@type GNAV.GridNode[]
    local neighbors = {}

    table.insert(neighbors, self:GetGridNode(GVector(gridNode.pos.x + 1, gridNode.pos.y, gridNode.pos.z)))
    table.insert(neighbors, self:GetGridNode(GVector(gridNode.pos.x - 1, gridNode.pos.y, gridNode.pos.z)))
    table.insert(neighbors, self:GetGridNode(GVector(gridNode.pos.x, gridNode.pos.y + 1, gridNode.pos.z)))
    table.insert(neighbors, self:GetGridNode(GVector(gridNode.pos.x, gridNode.pos.y - 1, gridNode.pos.z)))
    if not flat then
        table.insert(neighbors, self:GetGridNode(GVector(gridNode.pos.x, gridNode.pos.y, gridNode.pos.z + 1)))
        table.insert(neighbors, self:GetGridNode(GVector(gridNode.pos.x, gridNode.pos.y, gridNode.pos.z - 1)))
    end

    if filterFunc then
        neighbors =
            TUtil:Filter(
            neighbors,
            function(gridNode)
                return filterFunc(gridNode)
            end
        )
    end

    return neighbors
end

--- iterates until something is returned
---@generic R
---@param iterationFunc fun(gridNode: GNAV.GridNode) : R | nil
---@param z number? optional z coord
function GNAV.GridMap:IterateGridNodes(iterationFunc, z)
    local minX = self.boundary.x.min
    local minY = self.boundary.y.min
    local minZ = z or self.boundary.z.min
    local maxX = self.boundary.x.max
    local maxY = self.boundary.y.max
    local maxZ = z or self.boundary.z.max

    for x = minX, maxX do
        for y = minY, maxY do
            for z = minZ, maxZ do
                local r = iterationFunc(self:GetGridNode(GVector(x, y, z)))
                if r then
                    return r
                end
            end
        end
    end
end

---@class GNAV.GridArea.Options
---@field nodeList GNAV.GridNode[]
---@field gridMap GNAV.GridMap

---@class GNAV.GridArea
---@overload fun(options: GNAV.GridArea.Options) : GNAV.GridArea
GNAV.GridArea = Object:extend()

---@param options GNAV.GridArea.Options
function GNAV.GridArea:new(options)
    self.gridMap = options.gridMap
    self.nodeList = options.nodeList
    self.boundary = GNAV.Boundary()
    self.boundary:UpdateFromList(self.nodeList)
end

---@return number sizeX
---@return number sizeY
---@return number sizeZ
function GNAV.GridArea:GetSize()
    return self.boundary:GetSize()
end

---@param z number? optional Z to get 4 corners
---@return GNAV.GridNode[]
function GNAV.GridArea:GetCorners(z)
    if z then
        return {
            self.gridMap:GetGridNode(GVector(self.boundary.x.min, self.boundary.y.min, z)),
            self.gridMap:GetGridNode(GVector(self.boundary.x.max, self.boundary.y.max, z)),
            self.gridMap:GetGridNode(GVector(self.boundary.x.min, self.boundary.y.max, z)),
            self.gridMap:GetGridNode(GVector(self.boundary.x.max, self.boundary.y.min, z))
        }
    else
        return {
            self.gridMap:GetGridNode(GVector(self.boundary.x.min, self.boundary.y.min, self.boundary.z.min)),
            self.gridMap:GetGridNode(GVector(self.boundary.x.max, self.boundary.y.max, self.boundary.z.max)),
            self.gridMap:GetGridNode(GVector(self.boundary.x.min, self.boundary.y.min, self.boundary.z.max)),
            self.gridMap:GetGridNode(GVector(self.boundary.x.min, self.boundary.y.max, self.boundary.z.min)),
            self.gridMap:GetGridNode(GVector(self.boundary.x.min, self.boundary.y.max, self.boundary.z.max)),
            self.gridMap:GetGridNode(GVector(self.boundary.x.max, self.boundary.y.min, self.boundary.z.min)),
            self.gridMap:GetGridNode(GVector(self.boundary.x.max, self.boundary.y.min, self.boundary.z.max)),
            self.gridMap:GetGridNode(GVector(self.boundary.x.max, self.boundary.y.max, self.boundary.z.min))
        }
    end
end

function GNAV.GridArea:IsEmpty()
    for _, gridNode in ipairs(self.nodeList) do
        if not gridNode:IsEmpty() then
            return false
        end
    end
    return true
end

function GNAV.GridArea:IsUnknown()
    for _, gridNode in ipairs(self.nodeList) do
        if gridNode:IsUnknown() then
            return true
        end
    end
    return false
end

return GNAV
