local Object = require("GTurtle/classics")
local VU = require("GTurtle/vector_utils")
local expect = require("cc.expect")
local expect, field = expect.expect, expect.field

local GNAV = {}

-- Possible Look Directions (Relative)
GNAV.HEAD = {
    N = "N", -- North
    S = "S", -- South
    W = "W", -- West
    E = "E", -- East
}
-- Possible Turn Directions
GNAV.TURN = {
    L = "L", -- Left
    R = "R", -- Right
}

-- Possible Movement Directions
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

GNAV.PathNode = Object:extend()

function GNAV.PathNode:new(pos, lNode)
    self.pos = pos
    self.lNode = lNode
    self.nNode = nil
end

GNAV.GridNode = Object:extend()

function GNAV.GridNode:new(pos)
    self.pos = pos
    self.blockType = nil
    self.blockName = nil
end

function GNAV.GridNode:IsEmpty()
    return self.blockName == nil
end

GNAV.GridMap = Object:extend()

function GNAV.GridMap:new(initPos)
    -- 3D Array
    self.grid = {}
end

GNAV.GridNav = Object:extend()

function GNAV.GridNav:new(gTurtle, initPos)
    self.gTurtle = gTurtle
    self.head = GNAV.HEAD.N
    self.initPos = initPos
    self.pos = initPos
    self.path = {}
    self.gridMap = GNAV.GridMap()
    self:UpdatePosition()
end

function GNAV.GridNav:UpdatePosition()
    local lastNode = self.path[#self.path]

    local newNode = GNAV.PathNode(self.pos, lastNode)
    if lastNode then
        lastNode.nNode = newNode
    end
end

function GNAV.GridNav:Turn(turn)
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
end

function GNAV.GridNav:Move(dir)
    expect(1, dir, "string")
    local relVec = GNAV.M_VEC[self.head]
    if dir == GNAV.MOVE.B or dir == GNAV.MOVE.D then
        relVec = relVec * (-1)
    end
    self.pos = self.pos + relVec
    self:UpdatePosition()
end

function GNAV.GridNav:GetDistanceFromStart()
    return VU:Distance(self.pos, self.initPos)
end

function GNAV.GridNav:LogPos()
    self.gTurtle:Log(string.format("Pos: {%s} Head: %s", tostring(self.pos), self.head))
end

return GNAV
