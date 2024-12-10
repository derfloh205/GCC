local GTurtle = require("GCC/GTurtle/gturtle")
local GState = require("GCC/Util/gstate")
local TUtil = require("GCC/Util/tutil")
local TermUtil = require("GCC/Util/termutil")
local GVector = require("GCC/GNav/gvector")
local CONST = require("GCC/Util/const")
local f = string.format

---@class GTurtle.TurtleData.Rubber.Data.Serialized
---@field resourceChestPos GVector.Serialized
---@field produceChestPos GVector.Serialized
---@field treePositions GVector.Serialized[]
---@field fenceCorners GVector.Serialized[]

---@class GTurtle.TurtleData.Rubber.Data
---@field resourceChestPos GVector
---@field produceChestPos GVector
---@field treePositions GVector[]
---@field fenceCorners GVector[]

---@class GTurtle.TurtleData.Rubber : GTurtle.TurtleData
---@field data GTurtle.TurtleData.Rubber.Data

---@class GTurtle.RubberTurtle.Options : GTurtle.Base.Options

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
    ---@type GTurtle.TurtleData.Rubber
    self.turtleData = self.turtleData
    self.treeCount = 1
end

---@param data GTurtle.TurtleData.Rubber.Data
---@return GTurtle.TurtleData.Rubber.Data.Serialized
function RubberTurtle:SerializeTurtleData(data)
    return {
        resourceChestPos = data.resourceChestPos:Serialize(),
        produceChestPos = data.produceChestPos:Serialize(),
        fenceCorners = GVector:SerializeList(data.fenceCorners),
        treePositions = GVector:SerializeList(data.treePositions)
    }
end

---@param data GTurtle.TurtleData.Rubber.Data.Serialized
---@return GTurtle.TurtleData.Rubber.Data
function RubberTurtle:DeserializeTurtleData(data)
    return {
        resourceChestPos = GVector:Deserialize(data.resourceChestPos),
        produceChestPos = GVector:Deserialize(data.produceChestPos),
        fenceCorners = GVector:DeserializeList(data.fenceCorners),
        treePositions = GVector:DeserializeList(data.treePositions)
    }
end

function RubberTurtle:INIT()
    self:FLog("Initiating Rubber Turtle: %s", self.name)
    local rtData = self.turtleData.data --[[@as GTurtle.TurtleData.Rubber.Data]]

    if not rtData.resourceChestPos then
        rtData.resourceChestPos = TermUtil:ReadGVector("Resource Chest Position?")
    end
    if not rtData.produceChestPos then
        rtData.produceChestPos = TermUtil:ReadGVector("Produce Chest Position?")
    end

    if not rtData.fenceCorners then
        rtData.fenceCorners = rtData.fenceCorners or {}
        rtData.fenceCorners[1] = TermUtil:ReadGVector("Fence #1")
        rtData.fenceCorners[2] = TermUtil:ReadGVector("Fence #2")
        rtData.fenceCorners[3] = TermUtil:ReadGVector("Fence #3")
        rtData.fenceCorners[4] = TermUtil:ReadGVector("Fence #4")
    end

    self:WriteTurtleData()

    self.tnav:SetGeoFence(rtData.fenceCorners)

    self.resourceGN = self.tnav.gridMap:GetGridNode(rtData.resourceChestPos)
    self.resourceGN.unknown = false
    self.produceGN = self.tnav.gridMap:GetGridNode(rtData.produceChestPos)
    self.produceGN.unknown = false
    self.treeGNs =
        TUtil:Map(
        rtData.treePositions,
        function(treePositionGV)
            return self.tnav.gridMap:GetGridNode(treePositionGV)
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

---@return GNAV.GridNode? candidateGN
---@return GNAV.GridArea? candidateArea
function RubberTurtle:GetTreePositionCandidate()
    local requiredRadius = 1
    local z = self.tnav.currentGN.pos.z
    local maxGridSize = 15
    self.invalidTreeGNs = self.invalidTreeGNs or {}

    local result =
        self.tnav.gridMap:IterateGridNodes(
        function(gridNode)
            if gridNode:IsEmpty() then
                self:FLog("Tree Pos? %s", gridNode)
                local inFence = self.tnav.geoFence and self.tnav.geoFence:IsWithin(gridNode)
                self:FLog("- In Fence: %s", inFence)

                if inFence and not TUtil:tContains(self.invalidTreeGNs, gridNode) then
                    local area = self.tnav.gridMap:GetAreaAround(gridNode, requiredRadius)
                    local areaEmpty = area:IsEmpty()
                    local areaInFence = self.tnav.geoFence:IsAreaWithin(area)

                    if areaEmpty and areaInFence then
                        return {gridNode = gridNode, area = area}
                    else
                        table.insert(self.invalidTreeGNs, gridNode)
                    end
                    self:FLog("Invalid Area: %s E: %s F: %s", gridNode, areaEmpty, areaInFence)
                end
            end
        end,
        z
    )

    local gridX, gridY = self.tnav.gridMap:GetGridSize()

    if not result.gridNode then
        self:FLog("Could not find candidate for tree position (Grid Size: %d %d)", gridX, gridY)
    else
        return result.gridNode, result.area
    end
end

function RubberTurtle:EXPLORE_TREE_POSITIONS()
    local candidateGN, candidateArea = self:GetTreePositionCandidate()

    if candidateGN and candidateArea then
        self:FLog("Tree Candidate Position %s", tostring(candidateGN and candidateGN.pos))
        local success = self:NavigateToPosition(candidateGN.pos, true)
        if not success then
            self:Log("Not able to navigate to tree pos")
            table.insert(self.invalidTreeGNs, candidateGN)
            return
        end
        self:Log("Arrived at Candidate, Navigate to corners")
        local areaCorners = candidateArea:GetCorners(candidateGN.pos.z)
        -- navigate to area corners to inspect
        for _, cornerGN in ipairs(areaCorners) do
            local success = self:NavigateToPosition(cornerGN.pos, true)
            if not success then
                self:Log("Not able to inspect tree area")
                table.insert(self.invalidTreeGNs, candidateGN)
                return
            end
        end
        if candidateArea:IsEmpty() then
            self:FLog("Viable Tree Position Found: %s", candidateGN)
            table.insert(self.treeGNs, candidateGN)
            local rtData = self.turtleData.data
            table.insert(rtData.treePositions, candidateGN.pos)
            self:WriteTurtleData()
            self:SetState(RubberTurtle.STATE.DECIDE_ACTION)
        end
    else
        self:Log("No available tree pos candidate")
        self:SetState(RubberTurtle.STATE.EXIT)
    end
end

function RubberTurtle:DECIDE_ACTION()
    -- if no rubber sapling in inventory - fetch from resource chest
    if false then --not self:GetInventoryItem(CONST.ITEMS.RUBBER_SAPLINGS) then
        self:SetState(RubberTurtle.STATE.FETCH_SAPLINGS)
    elseif #self.treeGNs < self.treeCount then
        self:SetState(RubberTurtle.STATE.EXPLORE_TREE_POSITIONS)
    else
        self:SetState(RubberTurtle.STATE.EXIT)
    end
end

return RubberTurtle
