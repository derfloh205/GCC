local Object = require("GTurtle/classics")
local VU = require("GTurtle/vector_utils")
local expect = require("cc.expect")
local expect, field = expect.expect, expect.field

---@class GNAV
local GNAV = {}

--- Possible Look Directions (Relative)
---@enum GNAV.HEAD
GNAV.HEAD = {
    N = "N", -- North
    S = "S", -- South
    W = "W", -- West
    E = "E", -- East
}
--- Possible Turn Directions
---@enum GNAV.TURN
GNAV.TURN = {
    L = "L", -- Left
    R = "R", -- Right
}

--- Possible Movement Directions
---@enum GNAV.MOVE
GNAV.MOVE = {
    F = "F", -- Forward
    B = "B", -- Back
    U = "U", -- Up
    D = "D", -- Down
}

-- Absolute Vector Diffs based on Heading
GNAV.M_VEC = {
    [GNAV.HEAD.N] = vector.new(0, 1, 0),
    [GNAV.HEAD.S] = vector.new(0, 1, 0),
    [GNAV.HEAD.W] = vector.new(1, 0, 0),
    [GNAV.HEAD.E] = vector.new(1, 0, 0),
    [GNAV.MOVE.U] = vector.new(0, 0, 1),
    [GNAV.MOVE.D] = vector.new(0, 0, 1),
}

---@class GNAV.GridNode : Object
GNAV.GridNode = Object:extend()

function GNAV.GridNode:new(pos, blockData)
    self.pos = pos
    self.blockData = blockData
    -- wether the position ever was scannend
    self.unknown = false
end

function GNAV.GridNode:IsEmpty()
    return self.blockData == nil
end

function GNAV.GridNode:IsUnknown()
    return self.unknown
end

---@class GNAV.GridMap : Object
GNAV.GridMap = Object:extend()

function GNAV.GridMap:new(gridNav)
    self.gridNav = gridNav
    self.boundaries = {
        x = {max = 0, min = 0},
        y = {max = 0, min = 0},
        z = {max = 0, min = 0},
    }
    -- 3D Array
    self.grid = {}
    -- initialize with currentPos (which is seen as empty)
    self:UpdateGridNode(self.gridNav.pos, nil)
end

function GNAV.GridMap:UpdateBoundaries(pos)
    self.boundaries.x.min = math.min(self.boundaries.x.min, pos.x)
    self.boundaries.y.min = math.min(self.boundaries.y.min, pos.y)
    self.boundaries.z.min = math.min(self.boundaries.z.min, pos.z)

    self.boundaries.x.max = math.max(self.boundaries.x.max, pos.x)
    self.boundaries.y.max = math.max(self.boundaries.y.max, pos.y)
    self.boundaries.z.max = math.max(self.boundaries.z.max, pos.z)
end

--- initializes or updates a scanned grid node
function GNAV.GridMap:UpdateGridNode(pos, blockData)
    local gridNode = self:GetGridNode(pos)
    gridNode.blockData = blockData
    gridNode.unknown = false

    self:UpdateBoundaries(pos)
end

-- creates a new gridnode at pos or returns an existing one
function GNAV.GridMap:GetGridNode(pos)
    local x, y, z = pos.x, pos.y, pos.z
    self.grid[x] = self.grid[x] or {}
    self.grid[x][y] = self.grid[x][y] or {}
    local gridNode = self.grid[x][y][z]
    if not gridNode then
        gridNode = GNAV.GridNode(pos, nil)
        gridNode.unknown = true
        self.grid[x][y][z] = gridNode
    end
    return gridNode
end

function GNAV.GridMap:UpdateSurroundings()
    local nav = self.gridNav
    local scanData = self.gridNav.gTurtle:ScanBlocks()

    for dir, data in pairs(scanData) do
        local pos = self.gridNav:GetHeadedPosition(nav.pos, nav.head, dir)
        self:UpdateGridNode(pos, data)
    end
end

function GNAV.GridMap:LogGrid()
    self.gridNav.gTurtle:Log(textutils.serialise(self.grid))
end

function GNAV.GridMap:GetGridString(z)
    local boundaries = self.boundaries
    local minX = boundaries.x.min
    local minY = boundaries.y.min
    local maxX = boundaries.x.max
    local maxY = boundaries.y.max
    local gridString = ""
    for x = minX, maxX do
        for y = minY, maxY do
            local gridNode = self:GetGridNode(vector.new(x, y, z))
            local c = "O"
            if gridNode:IsEmpty() then c = " " end
            if gridNode:IsUnknown() then c = "?" end
            gridString = gridString .. c
        end
        gridString = gridString .. "\n"
    end
    return gridString
end

---@class GNAV.PathNode : Object
GNAV.PathNode = Object:extend()

function GNAV.PathNode:new(pos, lNode)
    self.pos = pos
    self.lNode = lNode
    self.nNode = nil
end

---@class GNAV.GridNav : Object
GNAV.GridNav = Object:extend()

function GNAV.GridNav:new(gTurtle, initPos)
    self.gTurtle = gTurtle
    self.head = GNAV.HEAD.N
    self.initPos = initPos
    self.pos = initPos
    self.path = {}
    self.gridMap = GNAV.GridMap(self)
    self:UpdatePath()
end

function GNAV.GridNav:UpdatePath()
    local lastNode = self.path[#self.path]

    local newNode = GNAV.PathNode(self.pos, lastNode)
    if lastNode then
        lastNode.nNode = newNode
    end
end

function GNAV.GridNav:OnTurn(turn)
    expect(1, turn, "string")
    local h = self.head
    if turn == GNAV.TURN.L then
        if h == GNAV.HEAD.N then
            self.head = GNAV.HEAD.W
        elseif h == GNAV.HEAD.W then
            self.head = GNAV.HEAD.S
        elseif h == GNAV.HEAD.S then
            self.head = GNAV.HEAD.E
        elseif h == GNAV.HEAD.E then
            self.head = GNAV.HEAD.N
        end
    elseif turn == GNAV.TURN.R then
        if h == GNAV.HEAD.N then
            self.head = GNAV.HEAD.E
        elseif h == GNAV.HEAD.E then
            self.head = GNAV.HEAD.S
        elseif h == GNAV.HEAD.S then
            self.head = GNAV.HEAD.W
        elseif h == GNAV.HEAD.W then
            self.head = GNAV.HEAD.N
        end
    end

    self.gridMap:UpdateSurroundings()
end

function GNAV.GridNav:OnMove(dir)
    expect(1, dir, "string")
    self.pos = self:GetHeadedPosition(self.pos, self.head, dir)
    self:UpdatePath()
    self.gridMap:UpdateSurroundings()
end

function GNAV.GridNav:GetDistanceFromStart()
    return VU:Distance(self.pos, self.initPos)
end

-- get pos by current pos, current heading and direction to look at
function GNAV.GridNav:GetHeadedPosition(pos, head, dir)
    local relVec = GNAV.M_VEC[head]
    if dir == GNAV.MOVE.B or dir == GNAV.MOVE.D then
        relVec = relVec * (-1)
    end
    return pos + relVec
end

function GNAV.GridNav:LogPos()
    self.gTurtle:Log(string.format("Pos: {%s} Head: %s", tostring(self.pos), self.head))
end

return GNAV
