local GTurtle = require("GCC/GTurtle/gturtle")
local GState = require("GCC/Util/gstate")
local TUtil = require("GCC/Util/tutil")
local TermUtil = require("GCC/Util/termutil")
local FUtil = require("GCC/Util/futil")
local SUtil = require("GCC/Util/sutil")
local VUtil = require("GCC/Util/vutil")
local CONST = require("GCC/Util/const")
local f = string.format

---@class GTurtle.TurtleData.Rubber.Data
---@field resourceChestPos Vector
---@field produceChestPos Vector

---@class GTurtle.TurtleData.Rubber : GTurtle.TurtleData
---@field data GTurtle.TurtleData.Rubber.Data

---@class GTurtle.RubberTurtle.Options : GTurtle.Base.Options
---@field treeCount number

---@class GTurtle.RubberTurtle : GTurtle.Base
---@overload fun(options: GTurtle.RubberTurtle.Options) : GTurtle.RubberTurtle
local RubberTurtle = GTurtle.Base:extend()

---@class GTurtle.RubberTurtle.STATE : GState.STATE
RubberTurtle.STATE = {
    EXPLORE_TREE_POSITIONS = "EXPLORE_TREE_POSITIONS",
    FETCH_SAPLINGS = "FETCH_SAPLINGS",
    SEARCH_TREE = "",
    DECIDE_ACTION = "DECIDE_ACTION"
}
TUtil:Inject(RubberTurtle.STATE, GState.STATE)

RubberTurtle.INVENTORY_WHITELIST = {
    CONST.ITEMS.RUBBER_SAPLINGS,
    CONST.ITEMS.RUBBER_WOOD
}

RubberTurtle.FUEL_BLACKLIST = {
    CONST.ITEMS.RUBBER_SAPLINGS,
    CONST.ITEMS.RUBBER_WOOD
}

---@param options GTurtle.RubberTurtle.Options
function RubberTurtle:new(options)
    options = options or {}
    options.fuelBlacklist = self.FUEL_BLACKLIST
    ---@diagnostic disable-next-line: redundant-parameter
    self.super.new(self, options)
    self.type = GTurtle.TYPES.RUBBER
    self.treeCount = options.treeCount or 1
    ---@type GTurtle.TurtleData.Rubber
    self.turtleData = self.turtleData
end

---@return GTurtle.TurtleData.Rubber.Data
function RubberTurtle:GetRTData()
    return self:GetTurtleData().data
end

function RubberTurtle:INIT()
    self:FLog("Initiating Rubber Turtle: %s", self.name)
    local rtData = self:GetRTData()

    if not rtData.produceChestPos or not rtData.resourceChestPos then
        rtData.resourceChestPos = TermUtil:ReadVector("Resource Chest Position?")
        rtData.produceChestPos = TermUtil:ReadVector("Produce Chest Position?")
    else
        self:Log("Loading Data from File:")
        self:FLog("Resource Chest Pos: %s", rtData.resourceChestPos)
        self:FLog("Produce Chest Pos: %s", rtData.produceChestPos)
    end
    rtData.treePositions = rtData.treePositions or {}
    self:WriteTurtleData()

    self.resourceGN = self.tnav.gridMap:GetGridNode(VUtil:Deserialize(rtData.resourceChestPos))
    self.resourceGN.unknown = false
    self.produceGN = self.tnav.gridMap:GetGridNode(VUtil:Deserialize(rtData.produceChestPos))
    self.produceGN.unknown = false
    self.treeGNs =
        TUtil:Map(
        rtData.treePositions,
        function(serializedPos)
            return self.tnav.gridMap:GetGridNode(VUtil:Deserialize(serializedPos))
        end
    )

    self:SetState(RubberTurtle.STATE.DECIDE_ACTION)
end

function RubberTurtle:FETCH_SAPLINGS()
    self:NavigateToPosition(self.resourceGN.pos)
    -- search for chest
    local chests =
        self.tnav:GetNeighbors(
        true,
        function(gn)
            return gn:IsChest()
        end
    )

    self:Log("Chest found? " .. tostring(#chests))

    if #chests == 0 then
        -- dance once to scan surroundings
        self:ExecuteMovement("RRRR")
        self:Log("Danced")
        chests =
            self.tnav:GetNeighbors(
            true,
            function(gn)
                return gn:IsChest()
            end
        )
    end

    local chestGN = chests[1]

    -- if still nothing here then user lied to us!
    if not chestGN then
        self:Log("Error: Resource Chest not found!")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end

    -- otherwise fetch saplings..
    self:Log("Turn to Chest")
    local relativeHead = self.tnav.currentGN:GetRelativeHeading(chestGN)
    self:TurnToHead(relativeHead)
    self:Log("Get Saplings..")
    self:SuckFromChest(CONST.ITEMS.RUBBER_SAPLINGS)
    self:DropExcept(self.INVENTORY_WHITELIST)

    self:SetState(RubberTurtle.STATE.DECIDE_ACTION)
end

---@return GTurtle.TNAV.GridNode? candidateGN
---@return GTurtle.TNAV.GridArea? candidateArea
function RubberTurtle:GetTreePositionCandidate()
    local requiredRadius = 3
    local z = self.tnav.currentGN.pos.z
    local maxGridSize = 15

    local candidateGN, candidateArea

    repeat
        for _, xData in pairs(self.tnav.gridMap.grid) do
            for _, yData in pairs(xData) do
                local gridNode = yData[z]

                local area = self.tnav.gridMap:GetAreaAround(gridNode, requiredRadius)

                if area:IsEmpty() then
                    return gridNode, candidateArea
                end
            end
        end

        self:Log("Could not find empty area, Increasing Grid")
        self.tnav.gridMap:IncreaseGridSize(1, 1, 0)

        local gridX, gridY = self.tnav.gridMap:GetGridSize()
    until candidateGN or (gridX > maxGridSize and gridY > maxGridSize)

    if not candidateGN then
        self:FLog("Could not find candidate for tree position (Grid Size: %d)", maxGridSize)
    end

    return candidateGN, candidateArea
end

function RubberTurtle:EXPLORE_TREE_POSITIONS()
    local candidateGN, candidateArea = self:GetTreePositionCandidate()

    self:FLog("Tree Candidate Position: %s", candidateGN)

    if candidateGN then
        local success = self:NavigateToPosition(candidateGN.pos)
    end
end

function RubberTurtle:DECIDE_ACTION()
    -- if no rubber sapling in inventory - fetch from resource chest
    if not self:GetInventoryItem(CONST.ITEMS.RUBBER_SAPLINGS) then
        self:SetState(RubberTurtle.STATE.FETCH_SAPLINGS)
    elseif #self.treeGNs < self.treeCount then
        self:SetState(RubberTurtle.STATE.EXPLORE_TREE_POSITIONS)
    else
        self:SetState(RubberTurtle.STATE.EXIT)
    end
end

return RubberTurtle
