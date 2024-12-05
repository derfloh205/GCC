local Object = require("GCC/Util/classics")
local VUtil = require("GCC/Util/vutil")
local TUtil = require("GCC/Util/tutil")
local f = string.format
local pretty = require("cc.pretty")

---@class GTurtle.TNAV
local TNAV = {}

--- Possible Look Directions (Relative)
---@enum GTurtle.TNAV.HEAD
TNAV.HEAD = {
    N = "N", -- North
    S = "S", -- South
    W = "W", -- West
    E = "E" -- East
}
--- Possible Turn Directions
---@enum GTurtle.TNAV.TURN
TNAV.TURN = {
    L = "L", -- Left
    R = "R" -- Right
}

--- Possible Movement Directions
---@enum GTurtle.TNAV.MOVE
TNAV.MOVE = {
    F = "F", -- Forward
    B = "B", -- Back
    U = "U", -- Up
    D = "D" -- Down
}

-- Absolute Vector Diffs based on Heading
TNAV.M_VEC = {
    [TNAV.HEAD.N] = vector.new(0, 1, 0),
    [TNAV.HEAD.S] = vector.new(0, 1, 0),
    [TNAV.HEAD.W] = vector.new(1, 0, 0),
    [TNAV.HEAD.E] = vector.new(1, 0, 0),
    [TNAV.MOVE.U] = vector.new(0, 0, 1),
    [TNAV.MOVE.D] = vector.new(0, 0, 1)
}

-- Required Heading by Vector Diff between adjacent positions
TNAV.M_HEAD = {
    [0] = {
        [0] = {
            [-1] = TNAV.MOVE.U,
            [1] = TNAV.MOVE.D
        },
        [-1] = {[0] = TNAV.HEAD.S},
        [1] = {[0] = TNAV.HEAD.N}
    },
    [1] = {
        [0] = {
            [0] = TNAV.HEAD.W
        }
    },
    [-1] = {
        [0] = {
            [0] = TNAV.HEAD.E
        }
    }
}

---@class GTurtle.TNAV.GridNode.Options
---@field gridMap GTurtle.TNAV.GridMap
---@field pos Vector
---@field blockData table?

---@class GTurtle.TNAV.GridNode : Object
---@overload fun(options: GTurtle.TNAV.GridNode.Options) : GTurtle.TNAV.GridNode
TNAV.GridNode = Object:extend()

---@param options GTurtle.TNAV.GridNode.Options
function TNAV.GridNode:new(options)
    options = options or {}
    self.gridMap = options.gridMap
    self.pos = options.pos
    self.blockData = options.blockData
    -- wether the position ever was scannend
    self.unknown = false
end

---@return boolean isEmpty
function TNAV.GridNode:IsEmpty()
    return self.blockData == nil
end

---@return boolean isOnPath
function TNAV.GridNode:IsOnPath()
    local path = self.gridMap.gridNav.activePath
    return TUtil:Find(
        path,
        function(gridNode)
            return VUtil:Equal(self.pos, gridNode.pos)
        end
    ) ~= nil
end

---@return boolean isUnknown
function TNAV.GridNode:IsUnknown()
    return self.unknown
end

---@return boolean isTurtlePos
function TNAV.GridNode:IsTurtlePos()
    return VUtil:Equal(self.pos, self.gridMap.gridNav.pos)
end

-- Get valid neighbors in 3D space - Used in A*
---@return GTurtle.TNAV.GridNode[]
function TNAV.GridNode:GetValidPathNeighbors()
    local boundaries = self.gridMap.boundaries
    local minX = boundaries.x.min
    local minY = boundaries.y.min
    local minZ = boundaries.z.min
    local maxX = boundaries.x.max
    local maxY = boundaries.y.max
    local maxZ = boundaries.z.max

    ---@type GTurtle.TNAV.GridNode[]
    local neighbors = {}
    local directions = {
        {x = 1, y = 0, z = 0}, -- Right
        {x = -1, y = 0, z = 0}, -- Left
        {x = 0, y = 1, z = 0}, -- Up
        {x = 0, y = -1, z = 0}, -- Down
        {x = 0, y = 0, z = 1}, -- Forward
        {x = 0, y = 0, z = -1} -- Backward
    }

    for _, dir in ipairs(directions) do
        local nx, ny, nz = self.pos.x + dir.x, self.pos.y + dir.y, self.pos.z + dir.z
        if nx >= minX and nx <= maxX and ny >= minY and ny <= maxY and nz >= minZ and nz <= maxZ then
            local neighborGridNode = self.gridMap:GetGridNode(vector.new(nx, ny, nz))
            if neighborGridNode then
                if neighborGridNode:IsEmpty() or neighborGridNode:IsUnknown() then
                    if (not self.gridMap.gridNav.avoidUnknown) or (not neighborGridNode:IsUnknown()) then
                        table.insert(neighbors, neighborGridNode)
                    end
                end
            end
        end
    end

    return neighbors
end

--- Using ManhattanDistance
---@param gridNode GTurtle.TNAV.GridNode
---@return number distance
function TNAV.GridNode:GetDistance(gridNode)
    return VUtil:ManhattanDistance(self.pos, gridNode.pos)
end

---@param gridNode GTurtle.TNAV.GridNode
---@return boolean equalPos
function TNAV.GridNode:EqualPos(gridNode)
    return VUtil:Equal(self.pos, gridNode.pos)
end

---@class GTurtle.TNAV.GridMap.Options
---@field gridNav GTurtle.TNAV.GridNav

---@class GTurtle.TNAV.GridMap : Object
---@overload fun(options: GTurtle.TNAV.GridMap.Options) : GTurtle.TNAV.GridMap
TNAV.GridMap = Object:extend()

---@param options GTurtle.TNAV.GridMap.Options
function TNAV.GridMap:new(options)
    options = options or {}
    self.gridNav = options.gridNav
    self.boundaries = {
        x = {max = self.gridNav.pos.x, min = self.gridNav.pos.x},
        y = {max = self.gridNav.pos.y, min = self.gridNav.pos.y},
        z = {max = self.gridNav.pos.z, min = self.gridNav.pos.z}
    }
    -- 3D Array
    ---@type table<number, table<number, table<number, GTurtle.TNAV.GridNode>>>
    self.grid = {}
    -- initialize with currentPos (which is seen as empty)
    self:UpdateGridNode(self.gridNav.pos, nil)
    self:UpdateSurroundings()
end

---@param pos Vector
function TNAV.GridMap:UpdateBoundaries(pos)
    self.boundaries.x.min = math.min(self.boundaries.x.min, pos.x)
    self.boundaries.y.min = math.min(self.boundaries.y.min, pos.y)
    self.boundaries.z.min = math.min(self.boundaries.z.min, pos.z)

    self.boundaries.x.max = math.max(self.boundaries.x.max, pos.x)
    self.boundaries.y.max = math.max(self.boundaries.y.max, pos.y)
    self.boundaries.z.max = math.max(self.boundaries.z.max, pos.z)
end

--- initializes or updates a scanned grid node
---@param pos Vector
---@param blockData table?
function TNAV.GridMap:UpdateGridNode(pos, blockData)
    local gridNode = self:GetGridNode(pos)
    gridNode.blockData = blockData or nil
    gridNode.unknown = false

    self:UpdateBoundaries(pos)
end

-- creates a new gridnode at pos or returns an existing one
---@param pos Vector
---@return GTurtle.TNAV.GridNode
function TNAV.GridMap:GetGridNode(pos)
    local x, y, z = pos.x, pos.y, pos.z
    self.grid[x] = self.grid[x] or {}
    self.grid[x][y] = self.grid[x][y] or {}
    local gridNode = self.grid[x][y][z]
    if not gridNode then
        gridNode =
            TNAV.GridNode(
            {
                gridMap = self,
                pos = pos
            }
        )
        gridNode.unknown = true
        self.grid[x][y][z] = gridNode
    end
    return gridNode
end

function TNAV.GridMap:UpdateSurroundings()
    local scanData = self.gridNav.gTurtle:ScanBlocks()
    --self.gridNav.gTurtle:Log("Scanning Surroundings..")

    for dir, data in pairs(scanData) do
        --self.gridNav.gTurtle:Log(f("%s -> %s", dir, (data and data.name or "Empty")))
        local pos = self.gridNav:GetHeadedPosition(self.gridNav.pos, self.gridNav.head, dir)
        self:UpdateGridNode(pos, data)
    end
end

function TNAV.GridMap:LogGrid()
    self.gridNav.gTurtle:Log(
        "Logging Grid at Z = " .. self.gridNav.pos.z .. "\n" .. self:GetGridString(self.gridNav.pos.z)
    )
end

---@param z number
---@return string
function TNAV.GridMap:GetGridString(z)
    local boundaries = self.boundaries
    local minX = boundaries.x.min
    local minY = boundaries.y.min
    local maxX = boundaries.x.max
    local maxY = boundaries.y.max
    local gridString = ""

    for y = minY, maxY do
        for x = minX, maxX do
            local gridNode = self:GetGridNode(vector.new(x, y, z))
            local c = " X "
            if gridNode:IsTurtlePos() then
                c = "[T]"
            elseif gridNode:IsEmpty() then
                if gridNode:IsOnPath() then
                    c = " . "
                else
                    c = "   "
                end
            elseif gridNode:IsUnknown() then
                c = " ? "
            end
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

---@class GTurtle.TNAV.Path.Options
---@field initGN GTurtle.TNAV.GridNode
---@field goalGN GTurtle.TNAV.GridNode
---@field nodeList GTurtle.TNAV.GridNode[]

---@class GTurtle.TNAV.Path : Object
---@overload fun(options: GTurtle.TNAV.Path.Options) : GTurtle.TNAV.Path
TNAV.Path = Object:extend()

---@param options GTurtle.TNAV.Path.Options
function TNAV.Path:new(options)
    options = options or {}
    self.nodeList = options.nodeList or {}
    self.initGN = options.initGN
    self.goalGN = options.goalGN
end

---@param currentGN GTurtle.TNAV.GridNode
---@return GTurtle.TNAV.GridNode?
function TNAV.Path:GetNextNode(currentGN)
    local _, index =
        TUtil:Find(
        self.nodeList,
        function(gridNode, index)
            return gridNode:EqualPos(currentGN)
        end
    )

    if not index then
        return
    end

    return self.nodeList[index + 1]
end

---@class GTurtle.TNAV.GridNav.Options
---@field gTurtle GTurtle.Base
---@field initialHead? GTurtle.TNAV.HEAD
---@field avoidUnknown? boolean

---@class GTurtle.TNAV.GridNav : Object
---@overload fun(options: GTurtle.TNAV.GridNav.Options) : GTurtle.TNAV.GridNav
TNAV.GridNav = Object:extend()

---@param options GTurtle.TNAV.GridNav.Options
function TNAV.GridNav:new(options)
    options = options or {}
    self.gTurtle = options.gTurtle
    ---@type GTurtle.TNAV.HEAD
    self.head = TNAV.HEAD.N
    -- try to locate initial pos via gps
    local gpsPos = self:GetGPSPos()
    self.gpsEnabled = gpsPos ~= nil
    self.initPos = gpsPos or vector.new(0, 0, 0)
    self.pos = self.initPos
    self.avoidUnknown = options.avoidUnknown or false
    ---@type GTurtle.TNAV.Path?
    self.activePath = nil
    self.gridMap = TNAV.GridMap({gridNav = self})

    if not options.initialHead and self.gpsEnabled then
        self:InitializeHeading()
    else
        self.head = options.initialHead
    end
end

function TNAV.GridNav:InitializeHeading()
    self.gTurtle:Log("Determine initial Heading..")
    -- try to move forward and back to determine initial heading via gps
    local moved = turtle.forward()
    local vecDiff
    if moved then
        local newPos = self:GetGPSPos()
        vecDiff = VUtil:Sub(self.pos, newPos)
        turtle.back()
    else
        moved = turtle.back()
        if moved then
            local newPos = self:GetGPSPos()
            vecDiff = VUtil:Sub(self.pos, newPos)
            turtle.forward()
        end
    end
    local head = TNAV.M_HEAD[vecDiff.x][vecDiff.y][vecDiff.z]
    if not head then
        self.gTurtle:Log("Could not determine heading..")
    else
        self.gTurtle:Log(f("Initial Heading: %s", head))
        self.head = head
    end
end

---@return Vector? pos
function TNAV.GridNav:GetGPSPos()
    local gpsPos = {gps.locate()}
    if gpsPos and #gpsPos == 3 then
        return vector.new(gpsPos[1], gpsPos[2], gpsPos[3])
    end
end

---@param turn GTurtle.TNAV.TURN
function TNAV.GridNav:OnTurn(turn)
    local h = self.head
    if turn == TNAV.TURN.L then
        if h == TNAV.HEAD.N then
            self.head = TNAV.HEAD.W
        elseif h == TNAV.HEAD.W then
            self.head = TNAV.HEAD.S
        elseif h == TNAV.HEAD.S then
            self.head = TNAV.HEAD.E
        elseif h == TNAV.HEAD.E then
            self.head = TNAV.HEAD.N
        end
    elseif turn == TNAV.TURN.R then
        if h == TNAV.HEAD.N then
            self.head = TNAV.HEAD.E
        elseif h == TNAV.HEAD.E then
            self.head = TNAV.HEAD.S
        elseif h == TNAV.HEAD.S then
            self.head = TNAV.HEAD.W
        elseif h == TNAV.HEAD.W then
            self.head = TNAV.HEAD.N
        end
    end

    self.gridMap:UpdateSurroundings()
end

---@param dir GTurtle.TNAV.MOVE
function TNAV.GridNav:OnMove(dir)
    self.pos = self:GetHeadedPosition(self.pos, self.head, dir)
    self.gridMap:UpdateSurroundings()
end

---@return number
function TNAV.GridNav:GetDistanceFromStart()
    return VUtil:ManhattanDistance(self.pos, self.initPos)
end

--- get pos by current pos, current heading and direction to look at
---@param pos Vector
---@param head GTurtle.TNAV.HEAD
---@param dir GTurtle.TNAV.MOVE
function TNAV.GridNav:GetHeadedPosition(pos, head, dir)
    -- use the z diff vector if dir is up or down else use the x/y vector
    local relVec = TNAV.M_VEC[dir] or TNAV.M_VEC[head]

    -- possible movement directions that cause coordination subtraction
    if
        dir == TNAV.MOVE.D or (head == TNAV.HEAD.W and dir == TNAV.MOVE.F) or
            (head == TNAV.HEAD.E and dir == TNAV.MOVE.B) or
            (head == TNAV.HEAD.N and dir == TNAV.MOVE.F) or
            (head == TNAV.HEAD.S and dir == TNAV.MOVE.B)
     then
        relVec = -relVec
    end
    return pos + relVec
end

function TNAV.GridNav:LogPos()
    self.gTurtle:Log(string.format("Pos: {%s} Head: %s", tostring(self.pos), self.head))
end

--- A*

--- Reconstruct the path from start to goal
--- Yes it uses table refs as keys *_*
---@param came_from table<GTurtle.TNAV.GridNode, GTurtle.TNAV.GridNode>
---@param current GTurtle.TNAV.GridNode
---@return GTurtle.TNAV.Path path
function TNAV.GridNav:ReconstructPathNodeList(came_from, current)
    local nodeList = {}
    while current do
        table.insert(nodeList, 1, current)
        current = came_from[current]
    end
    return nodeList
end

--- A* algorithm
---@param startGN GTurtle.TNAV.GridNode
---@param goalGN GTurtle.TNAV.GridNode
---@return GTurtle.TNAV.Path? path
function TNAV.GridNav:CalculatePath(startGN, goalGN)
    local boundaries = self.gridMap.boundaries
    local minX = boundaries.x.min
    local minY = boundaries.y.min
    local minZ = boundaries.z.min
    local maxX = boundaries.x.max
    local maxY = boundaries.y.max
    local maxZ = boundaries.z.max

    ---@type GTurtle.TNAV.GridNode[]
    local openSet = {startGN}
    local cameFromGN = {}

    -- Initialize cost dictionaries
    local gScore = {}
    local fScore = {}
    for x = minX, maxX do
        gScore[x], fScore[x] = {}, {}
        for y = minY, maxY do
            gScore[x][y], fScore[x][y] = {}, {}
            for z = minZ, maxZ do
                gScore[x][y][z] = math.huge
                fScore[x][y][z] = math.huge
            end
        end
    end

    gScore[startGN.pos.x][startGN.pos.y][startGN.pos.z] = 0
    fScore[startGN.pos.x][startGN.pos.y][startGN.pos.z] = startGN:GetDistance(goalGN)

    while #openSet > 0 do
        -- Find node in open_set with the lowest f_score
        table.sort(
            openSet,
            function(aGN, bGN)
                return fScore[aGN.pos.x][aGN.pos.y][aGN.pos.z] < fScore[bGN.pos.x][bGN.pos.y][bGN.pos.z]
            end
        )
        ---@type GTurtle.TNAV.GridNode
        local currentGN = table.remove(openSet, 1)

        -- If goal is reached
        if currentGN:EqualPos(goalGN) then
            return TNAV.Path {
                initGN = currentGN,
                goalGN = goalGN,
                nodeList = self:ReconstructPathNodeList(cameFromGN, currentGN)
            }
        end

        -- Process neighbors
        for _, neighborGN in ipairs(currentGN:GetValidPathNeighbors()) do
            local tentativeGScore = gScore[currentGN.pos.x][currentGN.pos.y][currentGN.pos.z] + 1
            if tentativeGScore < gScore[neighborGN.pos.x][neighborGN.pos.y][neighborGN.pos.z] then
                cameFromGN[neighborGN] = currentGN
                gScore[neighborGN.pos.x][neighborGN.pos.y][neighborGN.pos.z] = tentativeGScore
                fScore[neighborGN.pos.x][neighborGN.pos.y][neighborGN.pos.z] =
                    tentativeGScore + neighborGN:GetDistance(goalGN)
                if not TUtil:tContains(openSet, neighborGN) then
                    table.insert(openSet, neighborGN)
                end
            end
        end
    end

    return nil -- No path found
end

---@return GTurtle.TNAV.Path path?
function TNAV.GridNav:CalculatePathToInitialPosition()
    return self:CalculatePathToPosition(self.initPos)
end

---@param goalPos Vector
---@return GTurtle.TNAV.Path? path
function TNAV.GridNav:CalculatePathToPosition(goalPos)
    local startGN = self.gridMap:GetGridNode(self.pos)
    local goalGN = self.gridMap:GetGridNode(goalPos)

    if not goalGN or not startGN then
        return
    end

    return self:CalculatePath(startGN, goalGN)
end

---@param path GTurtle.TNAV.Path
function TNAV.GridNav:SetActivePath(path)
    self.activePath = path
end

---@return boolean
function TNAV.GridNav:IsInitialPosition()
    return VUtil:Equal(self.pos, self.initPos)
end

---@return (GTurtle.TNAV.MOVE | GTurtle.TNAV.TURN | nil) move?
function TNAV.GridNav:GetNextMoveAlongPath()
    if self:IsInitialPosition() or not self.activePath then
        return
    end

    local move
    local currentGN = self.gridMap:GetGridNode(self.pos)
    local nextGN = self.activePath:GetNextNode(currentGN)

    if nextGN then
        local nextPos = nextGN.pos
        -- Determine vector diff and needed turn or move to advance towards next gridNode
        local vecDiff = VUtil:Sub(self.pos, nextPos) -- e.g: [1, 1, 1] - [1, 2, 1] = [0, -1,  0]
        local requiredHead = TNAV.M_HEAD[vecDiff.x][vecDiff.y][vecDiff.z]

        if not requiredHead then
            self.gTurtle:Log("Could not determine next move!")
            self.gTurtle:Log(f("- VecDiff: %s)", tostring(vecDiff)))
            self.gTurtle:Log(f("- Pos: %s)", tostring(self.pos)))
            self.gTurtle:Log(f("- NextPos: %s)", tostring(nextPos)))
            return
        end
        self.gTurtle:Log(f("(%s) -> (%s) / (%s)", tostring(self.pos), tostring(nextPos), tostring(vecDiff)))
        self.gTurtle:Log(f("H: %s | R: %s", self.head, requiredHead))
        -- if the next pos is up or below directly return it as next move (no heading required)
        if requiredHead == TNAV.MOVE.U or requiredHead == TNAV.MOVE.D then
            return requiredHead
        end

        -- determine available move to reach the next position based on current heading and required heading
        if requiredHead == TNAV.HEAD.N then
            if self.head == TNAV.HEAD.N then
                return TNAV.MOVE.F
            elseif self.head == TNAV.HEAD.S then
                return TNAV.TURN.R
            elseif self.head == TNAV.HEAD.E then
                return TNAV.TURN.L
            elseif self.head == TNAV.HEAD.W then
                return TNAV.TURN.R
            end
        elseif requiredHead == TNAV.HEAD.S then
            if self.head == TNAV.HEAD.N then
                return TNAV.TURN.R
            elseif self.head == TNAV.HEAD.S then
                return TNAV.MOVE.F
            elseif self.head == TNAV.HEAD.E then
                return TNAV.TURN.R
            elseif self.head == TNAV.HEAD.W then
                return TNAV.TURN.L
            end
        elseif requiredHead == TNAV.HEAD.E then
            if self.head == TNAV.HEAD.N then
                return TNAV.TURN.R
            elseif self.head == TNAV.HEAD.S then
                return TNAV.TURN.L
            elseif self.head == TNAV.HEAD.E then
                return TNAV.MOVE.F
            elseif self.head == TNAV.HEAD.W then
                return TNAV.TURN.R
            end
        elseif requiredHead == TNAV.HEAD.W then
            if self.head == TNAV.HEAD.N then
                return TNAV.TURN.L
            elseif self.head == TNAV.HEAD.S then
                return TNAV.TURN.R
            elseif self.head == TNAV.HEAD.E then
                return TNAV.TURN.R
            elseif self.head == TNAV.HEAD.W then
                return TNAV.MOVE.F
            end
        end
    end

    self.gTurtle:Log("Could not determine next move on active path!")

    return move
end

return TNAV
