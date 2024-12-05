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

-- Relative Heading by Vector Diff between adjacent positions
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
---@field unknown? boolean

---@class GTurtle.TNAV.GridNode : Object
---@overload fun(options: GTurtle.TNAV.GridNode.Options) : GTurtle.TNAV.GridNode
TNAV.GridNode = Object:extend()

---@param options GTurtle.TNAV.GridNode.Options
function TNAV.GridNode:new(options)
    options = options or {}
    self.gridMap = options.gridMap
    self.pos = options.pos
    self:SetBlockData(options.blockData)
    self.unknown = options.unknown or false
end

function TNAV.GridNode:SetBlockData(blockData)
    self.blockData = blockData
    self.unknown = false
end

function TNAV.GridNode:SetEmpty()
    self:SetBlockData(nil)
end

---@return boolean isEmpty
function TNAV.GridNode:IsEmpty()
    return self.blockData == nil
end

---@return boolean isOnPath
function TNAV.GridNode:IsOnPath()
    if not self.gridMap.gridNav.activePath then
        return false
    end
    return self.gridMap.gridNav.activePath:IsOnPath(self)
end

---@return boolean isUnknown
function TNAV.GridNode:IsUnknown()
    return self.unknown
end

---@return boolean isTurtlePos
function TNAV.GridNode:IsTurtlePos()
    return self:EqualPos(self.gridMap.gridNav.currentGN)
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

---@param gridNode GTurtle.TNAV.GridNode
---@return GTurtle.TNAV.HEAD
function TNAV.GridNode:GetRelativeHeading(gridNode)
    local vecDiff = VUtil:Sub(self.pos, gridNode.pos)

    return TNAV.M_HEAD[vecDiff.x][vecDiff.y][vecDiff.z]
end

--- get relative pos by given heading and direction to look at
---@param head GTurtle.TNAV.HEAD
---@param dir GTurtle.TNAV.MOVE
function TNAV.GridNode:GetRelativeNode(head, dir)
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

    return self.gridMap:GetGridNode(self.pos + relVec)
end

function TNAV.GridNode:__tostring()
    local typeChar = ""
    if self:IsTurtlePos() then
        typeChar = "T"
    elseif self:IsEmpty() then
        typeChar = " "
    elseif self:IsUnknown() then
        typeChar = "?"
    else
        typeChar = "X"
    end
    return f("(%s)[%s] ", tostring(self.pos), typeChar)
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
    self.boundaries = nil
    -- 3D Array
    ---@type table<number, table<number, table<number, GTurtle.TNAV.GridNode>>>
    self.grid = {}
end

---@param gridNode GTurtle.TNAV.GridNode
function TNAV.GridMap:UpdateBoundaries(gridNode)
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

--- initializes or updates a scanned grid node
---@param pos Vector
---@param blockData table?
function TNAV.GridMap:UpdateGridNode(pos, blockData)
    local gridNode = self:GetGridNode(pos)
    gridNode.blockData = blockData or nil
    gridNode.unknown = false
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
    self:UpdateBoundaries(gridNode)
    return gridNode
end

function TNAV.GridMap:UpdateSurroundings()
    local scanLog = ""
    local scanData = self.gridNav.gTurtle:ScanBlocks()

    for dir, data in pairs(scanData) do
        scanLog = f("%s %s[%s]", scanLog, dir, (data and "X" or " "))
        local relativeNode = self.gridNav.currentGN:GetRelativeNode(self.gridNav.head, dir)
        if data then
            relativeNode:SetBlockData(data)
        else
            relativeNode:SetEmpty()
        end
    end

    self.gridNav.gTurtle:FLog("ScanLog: %s", scanLog)
end

function TNAV.GridMap:LogGrid()
    local z = self.gridNav.currentGN.pos.z
    local gridString = self:GetGridString(z)
    self.gridNav.gTurtle:Log(f("Logging Grid at Z = %d:\n%s", z, gridString))
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

---@param gridNode GTurtle.TNAV.GridNode
function TNAV.Path:IsOnPath(gridNode)
    local pathNode =
        TUtil:Find(
        self.nodeList,
        function(pathNode)
            return pathNode:EqualPos(gridNode)
        end
    )
    return pathNode ~= nil
end

---@param gridNode GTurtle.TNAV.GridNode
function TNAV.Path:IsGoal(gridNode)
    local goalNode = self.nodeList[#self.nodeList]
    if not goalNode then
        return false
    end

    return goalNode:EqualPos(gridNode)
end

function TNAV.Path:__tostring()
    local txt = ""
    for i, gridNode in ipairs(self.nodeList) do
        txt = f("%s[%d]: %s\n", txt, i, tostring(gridNode))
    end
    return txt
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

    local gpsPos = self:GetGPSPos()
    self.gpsEnabled = gpsPos ~= nil

    self.gridMap = TNAV.GridMap({gridNav = self})

    self.initGN = self.gridMap:GetGridNode(gpsPos or vector:new(0, 0, 0))
    self.initGN:SetEmpty()

    if not self.gpsEnabled then
        self.gTurtle:Log("No GPS Available. Initiate Relative Navigation")
    end

    self.currentGN = self.initGN

    self.avoidUnknown = options.avoidUnknown or false
    ---@type GTurtle.TNAV.Path?
    self.activePath = nil

    if not options.initialHead and self.gpsEnabled then
        local success = self:InitializeHeading()
        if not success then
            self.gTurtle:Log("Could not initialize Turtle Heading")
            return false
        end
    else
        self.head = options.initialHead or TNAV.HEAD.N
    end

    self.gTurtle:Log(f("Initial Heading: %s", self.head))

    self.gridMap:UpdateSurroundings()
end

---@return boolean success
function TNAV.GridNav:InitializeHeading()
    self.initializationAttempts = self.initializationAttempts or 0

    self.initializationAttempts = self.initializationAttempts + 1

    if self.initializationAttempts >= 2 then
        return false
    end

    self.gTurtle:Log("Determine initial Heading..")
    -- try to move forward and back to determine initial heading via gps
    local movedF = turtle.forward()
    local movedB = false
    if not movedF then
        movedB = turtle.back()
    end
    if not movedF and not movedB then
        self.gTurtle:Log("- Turning and trying again")
        turtle.turnLeft()
        return self:InitializeHeading() -- try again
    end

    local newGridNode = self.gridMap:GetGridNode(self:GetGPSPos())
    newGridNode:SetEmpty()

    local head
    if movedF then
        head = self.currentGN:GetRelativeHeading(newGridNode)
    elseif movedB then
        head = newGridNode:GetRelativeHeading(self.currentGN)
    end
    self.gTurtle:Log("- Heading: " .. tostring(head))

    if movedF then
        turtle.back()
    elseif movedB then
        turtle.forward()
    end

    if not head then
        return false
    else
        self.head = head
        return true
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
    self.currentGN = self.currentGN:GetRelativeNode(self.head, dir)
    self.gridMap:UpdateSurroundings()
end

---@return number
function TNAV.GridNav:GetDistanceFromStart()
    return self.currentGN:GetDistance(self.initGN)
end

function TNAV.GridNav:LogPos()
    self.gTurtle:Log(string.format("Pos: {%s} Head: %s", tostring(self.currentGN.pos), self.head))
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

    local calculations = 0
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

        calculations = calculations + 1

        -- to not run into a "did not yield" termination, yield every X calculations
        if calculations % 20 == 0 then
            sleep(0)
        end
    end

    return nil -- No path found
end

---@param goalPos Vector
---@return GTurtle.TNAV.Path? path
function TNAV.GridNav:CalculatePathToPosition(goalPos)
    local goalGN = self.gridMap:GetGridNode(goalPos)

    if not goalGN then
        return
    end

    return self:CalculatePath(self.currentGN, goalGN)
end

---@param path GTurtle.TNAV.Path
function TNAV.GridNav:SetActivePath(path)
    self.activePath = path
end

---@return (GTurtle.TNAV.MOVE | GTurtle.TNAV.TURN | nil) move?
---@return boolean? isGoal
function TNAV.GridNav:GetNextMoveAlongPath()
    self.gTurtle:Log("GetNextMoveAlongPath")

    if not self.activePath or self.activePath:IsGoal(self.currentGN) then
        self.gTurtle:Log("- Is initial position")
        return nil, true
    end

    self.gTurtle:Log("- Fetching new Move along Path")

    local move
    local currentGN = self.currentGN
    local nextGN = self.activePath:GetNextNode(currentGN)

    if nextGN then
        -- Determine vector diff and needed turn or move to advance towards next gridNode
        local requiredHead = currentGN:GetRelativeHeading(nextGN)

        if not requiredHead then
            self.gTurtle:Log("- Could not determine next move!")
            self.gTurtle:FLog("-> Pos: %s)", currentGN)
            self.gTurtle:FLog("-> NextPos: %s)", nextGN)
            return
        end
        self.gTurtle:FLog("- %s -> %s", currentGN, nextGN)
        self.gTurtle:FLog("- H: %s | R: %s", self.head, requiredHead)
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

    self.gTurtle:Log("- Could not determine next move on active path!")

    return move
end

return TNAV
