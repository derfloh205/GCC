local Object = require("GCC/Util/classics")
local GNAV = require("GCC/GNav/gnav")
local GVector = require("GCC/GNav/gvector")
local TUtil = require("GCC/Util/tutil")
local MUtil = require("GCC/Util/mutil")
local f = string.format

---@class GTurtle.TNAV
local TNAV = {}

TNAV.CALCULATIONS_PER_YIELD = 150

--- Possible Turn Directions
---@enum GTurtle.TNAV.TURN
TNAV.TURN = {
    L = "L", -- Left
    R = "R" -- Right
}

---@class TNAV.GeoFence.Options
---@field corners GNAV.GridNode

---@class TNAV.GeoFence : Object
---@overload fun(options: TNAV.GeoFence.Options) : TNAV.GeoFence
TNAV.GeoFence = Object:extend()

---@param options TNAV.GeoFence.Options
function TNAV.GeoFence:new(options)
    self.corners = options.corners or {}
    self.boundaries = {
        x = {min = 0, max = 0},
        y = {min = 0, max = 0},
        z = {min = 0, max = 0}
    }

    for _, node in ipairs(self.corners) do
        self.boundaries.x.min = math.min(self.boundaries.x.min, node.pos.x)
        self.boundaries.y.min = math.min(self.boundaries.y.min, node.pos.y)
        self.boundaries.z.min = math.min(self.boundaries.z.min, node.pos.z)

        self.boundaries.x.max = math.max(self.boundaries.x.max, node.pos.x)
        self.boundaries.y.max = math.max(self.boundaries.y.max, node.pos.y)
        self.boundaries.z.max = math.max(self.boundaries.z.max, node.pos.z)
    end
end

---@param gridNode GNAV.GridNode
---@return boolean IsWithin
function TNAV.GeoFence:IsWithin(gridNode)
    local inX = MUtil:InRange(gridNode.pos.x, self.boundaries.x.min, self.boundaries.x.max)
    local inY = MUtil:InRange(gridNode.pos.y, self.boundaries.y.min, self.boundaries.y.max)
    local inZ = MUtil:InRange(gridNode.pos.z, self.boundaries.z.min, self.boundaries.z.max)

    return inX and inY and inZ
end

---@class TNAV.Path.Options
---@field initGN GNAV.GridNode
---@field goalGN GNAV.GridNode
---@field nodeList GNAV.GridNode[]

---@class TNAV.Path : Object
---@overload fun(options: TNAV.Path.Options) : TNAV.Path
TNAV.Path = Object:extend()

---@param options TNAV.Path.Options
function TNAV.Path:new(options)
    options = options or {}
    self.nodeList = options.nodeList or {}
    self.initGN = options.initGN
    self.goalGN = options.goalGN
end

---@param currentGN GNAV.GridNode
---@return GNAV.GridNode?
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

---@param gridNode GNAV.GridNode
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

---@param gridNode GNAV.GridNode
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

---@class TNAV.GridNav.Options
---@field gTurtle GTurtle.Base
---@field initialHead? GNAV.HEAD
---@field avoidUnknown? boolean
---@field avoidAllBlocks? boolean true: avoid all blocks, false: only avoid blocks in blacklist
---@field blockBlacklist? string[] -- used if avoidBlocks is false
---@field gridFile? string
---@field fenceCorners? GVector[]

---@class TNAV.GridNav : Object
---@overload fun(options: TNAV.GridNav.Options) : TNAV.GridNav
TNAV.GridNav = Object:extend()

---@param options TNAV.GridNav.Options
function TNAV.GridNav:new(options)
    options = options or {}
    self.gTurtle = options.gTurtle
    self.avoidAllBlocks = options.avoidAllBlocks == nil or options.avoidAllBlocks
    self.blockBlacklist = options.blockBlacklist or {}
    self.gridFile = options.gridFile

    local gpsPos = self:GetGPSPos()
    self.gpsEnabled = gpsPos ~= nil

    self.gridMap =
        GNAV.GridMap(
        {
            logger = self.gTurtle,
            saveFile = self.gridFile,
            loadFile = self.gridFile,
            gridNodeMapFunc = function(gridNode)
                if gridNode:EqualPos(self.currentGN) then
                    return "[T]"
                elseif self.activePath and self.activePath:IsOnPath(gridNode) then
                    return " . "
                end
            end
        }
    )

    self.initGN = self.gridMap:GetGridNode(gpsPos or GVector(0, 0, 0))
    self.initGN:SetEmpty()

    if not self.gpsEnabled then
        self.gTurtle:Log("No GPS Available. Initiate Relative Navigation")
    end

    self.currentGN = self.initGN

    self.avoidUnknown = options.avoidUnknown or false
    ---@type TNAV.Path?
    self.activePath = nil

    if not options.initialHead and self.gpsEnabled then
        local success = self:InitializeHeading()
        if not success then
            self.gTurtle:Log("Could not initialize Turtle Heading")
            return false
        end
    else
        self.head = options.initialHead or GNAV.HEAD.N
    end

    self.gTurtle:Log(f("Initial Heading: %s", self.head))

    self:UpdateSurroundings()

    if options.fenceCorners then
        self:SetGeoFence(options.fenceCorners)
    end
end

---@param corners GVector[]
function TNAV.GridNav:SetGeoFence(corners)
    self.geoFence =
        TNAV.GeoFence {
        corners = TUtil:Map(
            corners,
            function(pos)
                return self.gridMap:GetGridNode(pos)
            end
        )
    }
end

---@return boolean success
function TNAV.GridNav:InitializeHeading()
    self.initializationAttempts = self.initializationAttempts or 0

    self.initializationAttempts = self.initializationAttempts + 1

    if self.initializationAttempts > 2 then
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

---@return GVector? pos
function TNAV.GridNav:GetGPSPos()
    local gpsPos = {gps.locate()}
    if gpsPos and #gpsPos == 3 then
        return GVector(gpsPos[1], gpsPos[2], gpsPos[3])
    end
end

---@param turn GTurtle.TNAV.TURN
function TNAV.GridNav:OnTurn(turn)
    local h = self.head
    if turn == TNAV.TURN.L then
        if h == GNAV.HEAD.N then
            self.head = GNAV.HEAD.W
        elseif h == GNAV.HEAD.W then
            self.head = GNAV.HEAD.S
        elseif h == GNAV.HEAD.S then
            self.head = GNAV.HEAD.E
        elseif h == GNAV.HEAD.E then
            self.head = GNAV.HEAD.N
        end
    elseif turn == TNAV.TURN.R then
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

    self:UpdateSurroundings()
end

---@param dir GNAV.DIR
function TNAV.GridNav:OnMove(dir)
    self.currentGN = self.currentGN:GetRelativeNode(self.head, dir)
    self.currentGN.visited = true
    self:UpdateSurroundings()
end

---@return number
function TNAV.GridNav:GetDistanceFromStart()
    return self.currentGN:GetDistance(self.initGN)
end

function TNAV.GridNav:LogPos()
    self.gTurtle:Log(string.format("Pos: {%s} Head: %s", tostring(self.currentGN.pos), self.head))
end

function TNAV.GridNav:UpdateSurroundings()
    local scanLog = ""
    local scanData = self.gTurtle:ScanBlocks()

    for dir, data in pairs(scanData) do
        scanLog = f("%s %s[%s]", scanLog, dir, (data and "X" or " "))
        local relativeNode = self.currentGN:GetRelativeNode(self.head, dir)
        if data then
            relativeNode:SetBlockData(data)
        else
            relativeNode:SetEmpty()
        end
    end

    self.gTurtle:FLog("Updated Surroundings: %s", scanLog)
    self.gridMap:WriteFile()
end

---@param flat boolean? ignores neighbors of different Z
---@param filterFunc? fun(gn: GNAV.GridNode): boolean
---@return GNAV.GridNode[]
function TNAV.GridNav:GetNeighbors(flat, filterFunc)
    return self.gridMap:GetNeighborsOf(self.currentGN, flat, filterFunc)
end

--- A*

--- Reconstruct the path from start to goal
--- Yes it uses table refs as keys *_*
---@param came_from table<GNAV.GridNode, GNAV.GridNode>
---@param current GNAV.GridNode
---@return TNAV.Path path
function TNAV.GridNav:ReconstructPathNodeList(came_from, current)
    local nodeList = {}
    while current do
        table.insert(nodeList, 1, current)
        current = came_from[current]
    end
    return nodeList
end

-- Get valid neighbors in 3D space - Used in A*
---@param gridNode GNAV.GridNode
---@param flat? boolean
---@return GNAV.GridNode[]
function TNAV.GridNav:GetValidPathNeighbors(gridNode, flat)
    ---@type GNAV.GridNode[]
    local neighbors = {}

    neighbors =
        self.gridMap:GetNeighborsOf(
        gridNode,
        flat,
        function(neighborGridNode)
            local isEmpty = neighborGridNode:IsEmpty()
            local allowUnknown = not self.avoidUnknown or not neighborGridNode:IsUnknown()
            local allBlocksAllowed = not self.avoidAllBlocks
            local notBlacklisted =
                (not isEmpty) and (not TUtil:tContains(self.blockBlacklist, neighborGridNode.blockData.name))

            if self.geoFence and not self.geoFence:IsWithin(neighborGridNode) then
                return false
            end

            if isEmpty then
                if allowUnknown then
                    return true
                end
            else
                if allBlocksAllowed and notBlacklisted then
                    return true
                end
            end
            return false
        end
    )

    return neighbors
end

--- A* algorithm
---@param startGN GNAV.GridNode
---@param goalGN GNAV.GridNode
---@param flat? boolean
---@return TNAV.Path? path
function TNAV.GridNav:CalculatePath(startGN, goalGN, flat)
    self.gTurtle:FLog("Calculating Path: %s -> %s", startGN, goalGN)

    ---@type GNAV.GridNode[]
    local openSet = {startGN}
    local cameFromGN = {}

    -- Initialize cost dictionaries
    local gScore = {}
    local fScore = {}

    local function GetGScore(gn)
        local pos = gn.pos
        local x, y, z = pos.x, pos.y, pos.z
        gScore[x] = gScore[x] or {}
        gScore[x][y] = gScore[x][y] or {}
        gScore[x][y][z] = gScore[x][y][z] or math.huge
        return gScore[x][y][z]
    end

    local function SetGScore(gn, score)
        local pos = gn.pos
        local x, y, z = pos.x, pos.y, pos.z
        gScore[x] = gScore[x] or {}
        gScore[x][y] = gScore[x][y] or {}
        gScore[x][y][z] = score
    end
    local function GetFScore(gn)
        local pos = gn.pos
        local x, y, z = pos.x, pos.y, pos.z
        fScore[x] = fScore[x] or {}
        fScore[x][y] = fScore[x][y] or {}
        fScore[x][y][z] = fScore[x][y][z] or math.huge
        return fScore[x][y][z]
    end

    local function SetFScore(gn, score)
        local pos = gn.pos
        local x, y, z = pos.x, pos.y, pos.z
        fScore[x] = fScore[x] or {}
        fScore[x][y] = fScore[x][y] or {}
        fScore[x][y][z] = score
    end

    SetGScore(startGN, 0)
    SetFScore(startGN, startGN:GetDistance(goalGN))

    local calculations = 0
    while #openSet > 0 do
        -- Find node in open_set with the lowest f_score
        table.sort(
            openSet,
            function(aGN, bGN)
                return GetFScore(aGN) < GetFScore(bGN)
            end
        )
        ---@type GNAV.GridNode
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
        for _, neighborGN in ipairs(self:GetValidPathNeighbors(currentGN, flat)) do
            local tentativeGScore = GetGScore(currentGN) + 1
            if tentativeGScore < GetGScore(neighborGN) then
                cameFromGN[neighborGN] = currentGN
                SetGScore(neighborGN, tentativeGScore)
                SetFScore(neighborGN, tentativeGScore + neighborGN:GetDistance(goalGN))
                if not TUtil:tContains(openSet, neighborGN) then
                    table.insert(openSet, neighborGN)
                end
            end
        end

        calculations = calculations + 1

        -- to not run into a "did not yield" termination, yield every X calculations
        if calculations % TNAV.CALCULATIONS_PER_YIELD == 0 then
            self.gTurtle:FLog("- Dist: %d Calcs: %d", math.floor(currentGN:GetDistance(goalGN)), calculations)
            sleep(0)
        end
    end

    return nil -- No path found
end

---@param goalPos GVector
---@param flat? boolean
---@return TNAV.Path? path
function TNAV.GridNav:CalculatePathToPosition(goalPos, flat)
    local goalGN = self.gridMap:GetGridNode(goalPos)

    if not goalGN then
        return
    end

    return self:CalculatePath(self.currentGN, goalGN, flat)
end

---@param path TNAV.Path
function TNAV.GridNav:SetActivePath(path)
    self.activePath = path
end

---@return (GNAV.DIR | GNAV.HEAD | nil) move?
---@return boolean? isGoal
function TNAV.GridNav:GetNextMoveAlongPath()
    self.gTurtle:Log("GetNextMoveAlongPath")

    if not self.activePath or self.activePath:IsGoal(self.currentGN) then
        self.gTurtle:Log("- Is target position")
        return nil, true
    end

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

        -- if heading is not required heading, return required heading
        if self.head ~= requiredHead then
            self.gTurtle:FLog("- H: %s | R: %s", self.head, requiredHead)
            return requiredHead
        end

        self.gTurtle:FLog("- %s -> %s", currentGN, nextGN)

        -- if the next pos is up or below directly return it as next move (no heading required)
        if requiredHead == GNAV.DIR.U or requiredHead == GNAV.DIR.D then
            return requiredHead
        end

        -- otherwise forward movement is sufficient
        return GNAV.DIR.F
    end

    self.gTurtle:Log("- Could not determine next move on active path!")

    return move
end

return TNAV
