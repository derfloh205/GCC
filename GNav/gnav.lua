local Object = require("GCC/Util/classics")
local GVector = require("GCC/GNav/gvector")
local TUtil = require("GCC/Util/tutil")
local MUtil = require("GCC/Util/mutil")
local CONST = require("GCC/Util/const")
local f = string.format

---@class GNAV
local GNAV = {}

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
    if self:IsEmpty() or self:IsUnknown() then
        return false
    end
    return TUtil:tContains(CONST.CHEST_BLOCKS, self.blockData.name)
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

---@class GNAV.GridMap.Options
---@field logger GLogAble
---@field gridNodeMapFunc? fun(gridNode: GNAV.GridNode): string?
---@field saveFile? string if set save grid to file continously
---@field loadFile? string if set attempt to load data from file at initialization

---@class GNAV.GridMap : Object
---@overload fun(options: GNAV.GridMap.Options) : GNAV.GridMap
GNAV.GridMap = Object:extend()

---@param options GNAV.GridMap.Options
function GNAV.GridMap:new(options)
    options = options or {}
    self.logger = options.logger
    self.boundaries = nil
    -- 3D Array
    ---@type table<number, table<number, table<number, GNAV.GridNode>>>
    self.grid = {}
    self.gridNodeMapFunc = options.gridNodeMapFunc

    self.saveFile = options.saveFile
    self.loadFile = options.loadFile

    if self.loadFile and fs.exists(self.loadFile) then
        local loadFile = fs.open(self.loadFile, "r")
        -- serialized -> no functions or metatables, only base types (table, number, string ...)
        local serializedGridMap = textutils.unserialiseJSON(loadFile.readAll())
        self:DeserializeGrid(serializedGridMap)
        loadFile.close()
    end
end

---@param serializedGridMap table
function GNAV.GridMap:DeserializeGrid(serializedGridMap)
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

---@return table serializedGrid
function GNAV.GridMap:SerializeGrid()
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

---@param gridNode GNAV.GridNode
function GNAV.GridMap:UpdateBoundaries(gridNode)
    -- init with gridNode positions
    self.boundaries =
        self.boundaries or
        {
            x = {max = gridNode.pos.x, min = gridNode.pos.x},
            y = {max = gridNode.pos.y, min = gridNode.pos.y},
            z = {max = gridNode.pos.z, min = gridNode.pos.z}
        }
    self.boundaries.x.min = math.min(self.boundaries.x.min, gridNode.pos.x)
    self.boundaries.y.min = math.min(self.boundaries.y.min, gridNode.pos.y)
    self.boundaries.z.min = math.min(self.boundaries.z.min, gridNode.pos.z)

    self.boundaries.x.max = math.max(self.boundaries.x.max, gridNode.pos.x)
    self.boundaries.y.max = math.max(self.boundaries.y.max, gridNode.pos.y)
    self.boundaries.z.max = math.max(self.boundaries.z.max, gridNode.pos.z)
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
    self:UpdateBoundaries(gridNode)
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
    local sizeX = self.boundaries.x.max - self.boundaries.x.min
    local sizeY = self.boundaries.y.max - self.boundaries.y.min
    local sizeZ = self.boundaries.z.max - self.boundaries.z.min

    return sizeX, sizeY, sizeZ
end

---@param z number
---@param boundaries table
---@return string gridString
function GNAV.GridMap:GetGridStringByBoundary(z, boundaries)
    local minX = boundaries.x.min
    local minY = boundaries.y.min
    local maxX = boundaries.x.max
    local maxY = boundaries.y.max
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
    return self:GetGridStringByBoundary(z, self.boundaries)
end

---@param centerPos GVector
---@param sizeX number
---@param sizeY? number
---@return string gridString
function GNAV.GridMap:GetCenteredGridString(centerPos, sizeX, sizeY)
    sizeY = sizeY or sizeX
    local boundaries = {
        x = {
            min = centerPos.x - math.floor(sizeX / 2),
            max = centerPos.x + math.ceil(sizeX / 2)
        },
        y = {
            min = centerPos.y - math.floor(sizeY / 2),
            max = centerPos.y + math.ceil(sizeY / 2)
        }
    }
    return self:GetGridStringByBoundary(centerPos.z, boundaries)
end

function GNAV.GridMap:Log(txt)
    if self.logger then
        self.logger:Log(txt)
    end
end
function GNAV.GridMap:FLog(...)
    if self.logger then
        self.logger:FLog(...)
    end
end

function GNAV.GridMap:IncreaseGridSize(incX, incY, incZ)
    self:Log("Increasing Grid Size..")
    for x = self.boundaries.x.min - incX, self.boundaries.x.max + incX do
        if not MUtil:InRange(x, self.boundaries.x.min, self.boundaries.x.max) then
            for y = self.boundaries.y.min - incY, self.boundaries.y.max + incY do
                if not MUtil:InRange(y, self.boundaries.y.min, self.boundaries.y.max) then
                    for z = self.boundaries.z.min - incZ, self.boundaries.z.max + incZ do
                        if not MUtil:InRange(z, self.boundaries.z.min, self.boundaries.z.max) then
                            self:GetGridNode(GVector(x, y, z))
                        end
                    end
                end
            end
        end
    end
    self:Log("Increased")
end

---@param gridNode GNAV.GridNode
---@param flat? boolean
---@param filterFunc fun(gridNode: GNAV.GridNode) : boolean
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
    local minX = self.boundaries.x.min
    local minY = self.boundaries.y.min
    local minZ = z or self.boundaries.z.min
    local maxX = self.boundaries.x.max
    local maxY = self.boundaries.y.max
    local maxZ = z or self.boundaries.z.max

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
    self.boundaries = {
        x = {min = 0, max = 0},
        y = {min = 0, max = 0},
        z = {min = 0, max = 0}
    }

    for _, gridNode in ipairs(self.nodeList) do
        self.boundaries.x.min = math.min(self.boundaries.x.min, gridNode.pos.x)
        self.boundaries.y.min = math.min(self.boundaries.y.min, gridNode.pos.y)
        self.boundaries.z.min = math.min(self.boundaries.z.min, gridNode.pos.z)

        self.boundaries.x.max = math.max(self.boundaries.x.max, gridNode.pos.x)
        self.boundaries.y.max = math.max(self.boundaries.y.max, gridNode.pos.y)
        self.boundaries.z.max = math.max(self.boundaries.z.max, gridNode.pos.z)
    end

    self.sizeX = self.boundaries.x.max - self.boundaries.x.min
    self.sizeY = self.boundaries.y.max - self.boundaries.y.min
    self.sizeZ = self.boundaries.z.max - self.boundaries.z.min
end

---@param z number? optional Z to get 4 corners
---@return GNAV.GridNode[]
function GNAV.GridArea:GetCorners(z)
    if z then
        return {
            self.gridMap:GetGridNode(GVector(self.boundaries.x.min, self.boundaries.y.min, z)),
            self.gridMap:GetGridNode(GVector(self.boundaries.x.max, self.boundaries.y.max, z)),
            self.gridMap:GetGridNode(GVector(self.boundaries.x.min, self.boundaries.y.max, z)),
            self.gridMap:GetGridNode(GVector(self.boundaries.x.max, self.boundaries.y.min, z))
        }
    else
        return {
            self.gridMap:GetGridNode(GVector(self.boundaries.x.min, self.boundaries.y.min, self.boundaries.z.min)),
            self.gridMap:GetGridNode(GVector(self.boundaries.x.max, self.boundaries.y.max, self.boundaries.z.max)),
            self.gridMap:GetGridNode(GVector(self.boundaries.x.min, self.boundaries.y.min, self.boundaries.z.max)),
            self.gridMap:GetGridNode(GVector(self.boundaries.x.min, self.boundaries.y.max, self.boundaries.z.min)),
            self.gridMap:GetGridNode(GVector(self.boundaries.x.min, self.boundaries.y.max, self.boundaries.z.max)),
            self.gridMap:GetGridNode(GVector(self.boundaries.x.max, self.boundaries.y.min, self.boundaries.z.min)),
            self.gridMap:GetGridNode(GVector(self.boundaries.x.max, self.boundaries.y.min, self.boundaries.z.max)),
            self.gridMap:GetGridNode(GVector(self.boundaries.x.max, self.boundaries.y.max, self.boundaries.z.min))
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
