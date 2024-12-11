local GTurtle = require("GCC/GTurtle/gturtle")
local GState = require("GCC/Util/gstate")
local TUtil = require("GCC/Util/tutil")
local TermUtil = require("GCC/Util/termutil")
local GVector = require("GCC/GNav/gvector")
local CONST = require("GCC/Util/const")
local f = string.format

---@class GTurtle.TurtleB.Rubber.Data.Serialized
---@field resourceChestPos GVector.Serialized
---@field produceChestPos GVector.Serialized
---@field treePositions GVector.Serialized[]
---@field fenceCorners GVector.Serialized[]
---@field treeCount number

---@class GTurtle.TurtleDB.Rubber.Data
---@field resourceChestPos GVector
---@field produceChestPos GVector
---@field treePositions GVector[]
---@field fenceCorners GVector[]
---@field treeCount number

---@class GTurtle.TurtleDB.Rubber : GTurtle.TurtleDB
---@field data GTurtle.TurtleDB.Rubber.Data

---@class GTurtle.RubberTurtle.Options : GTurtle.Base.Options

---@class GTurtle.RubberTurtle : GTurtle.Base
---@overload fun(options: GTurtle.RubberTurtle.Options) : GTurtle.RubberTurtle
local RubberTurtle = GTurtle.Base:extend()

---@class GTurtle.RubberTurtle.STATE : GState.STATE
RubberTurtle.STATE = {
    EXPLORE_TREE_POSITIONS = "EXPLORE_TREE_POSITIONS",
    FETCH_SAPLINGS = "FETCH_SAPLINGS",
    SEARCH_TREE = "",
    DECIDE_ACTION = "DECIDE_ACTION",
    REFUEL = "REFUEL",
    REQUEST_FUEL = "REQUEST_FUEL"
}
TUtil:Inject(RubberTurtle.STATE, GState.STATE)

RubberTurtle.RESOURCE_CHEST_ITEMS = {}

RubberTurtle.PRODUCE_CHEST_ITEMS = {
    CONST.ITEMS.RUBBER_WOOD,
    CONST.ITEMS.RESIN,
    CONST.ITEMS.RUBBER_LEAVES
}

---@param options GTurtle.RubberTurtle.Options
function RubberTurtle:new(options)
    options = options or {}
    options.fuelBlacklist = self.FUEL_BLACKLIST
    ---@diagnostic disable-next-line: redundant-parameter
    self.super.new(self, options)
    self.type = GTurtle.TYPES.RUBBER
    ---@type GTurtle.TurtleDB.Rubber
    self.turtleDB = self.turtleDB
    self.treeCount = 1
end

---@param data GTurtle.TurtleDB.Rubber.Data
---@return GTurtle.TurtleB.Rubber.Data.Serialized
function RubberTurtle:SerializeTurtleDB(data)
    return {
        resourceChestPos = data.resourceChestPos:Serialize(),
        produceChestPos = data.produceChestPos:Serialize(),
        fenceCorners = GVector:SerializeList(data.fenceCorners),
        treePositions = GVector:SerializeList(data.treePositions),
        treeCount = data.treeCount
    }
end

---@param data GTurtle.TurtleB.Rubber.Data.Serialized
---@return GTurtle.TurtleDB.Rubber.Data
function RubberTurtle:DeserializeTurtleDB(data)
    return {
        resourceChestPos = GVector:Deserialize(data.resourceChestPos),
        produceChestPos = GVector:Deserialize(data.produceChestPos),
        fenceCorners = GVector:DeserializeList(data.fenceCorners),
        treePositions = GVector:DeserializeList(data.treePositions),
        treeCount = data.treeCount
    }
end

function RubberTurtle:INIT()
    self:FLog("Initiating Rubber Turtle: %s", self.name)
    local turtleDB = self.turtleDB.data --[[@as GTurtle.TurtleDB.Rubber.Data]]

    if not turtleDB.resourceChestPos then
        turtleDB.resourceChestPos = TermUtil:ReadGVector("Resource Chest Position?")
    end
    if not turtleDB.produceChestPos then
        turtleDB.produceChestPos = TermUtil:ReadGVector("Produce Chest Position?")
    end

    if not turtleDB.fenceCorners or #turtleDB.fenceCorners < 4 then
        turtleDB.fenceCorners = turtleDB.fenceCorners or {}
        turtleDB.fenceCorners[1] = TermUtil:ReadGVector("Fence #1")
        turtleDB.fenceCorners[2] = TermUtil:ReadGVector("Fence #2")
        turtleDB.fenceCorners[3] = TermUtil:ReadGVector("Fence #3")
        turtleDB.fenceCorners[4] = TermUtil:ReadGVector("Fence #4")
    end

    if not turtleDB.treeCount then
        turtleDB.treeCount = TermUtil:ReadNumber("Tree Count?")
        self.treeCount = turtleDB.treeCount
    end

    turtleDB.treePositions = turtleDB.treePositions or {}

    self.invalidTreeGNs =
        TUtil:Map(
        turtleDB.treePositions,
        function(gvector)
            return self.tnav.gridMap:GetGridNode(gvector)
        end
    )

    self:PersistTurtleDB()

    self.tnav:SetGeoFence(turtleDB.fenceCorners)

    self.resourceGN = self.tnav.gridMap:GetGridNode(turtleDB.resourceChestPos)
    self.resourceGN.unknown = false
    self.produceGN = self.tnav.gridMap:GetGridNode(turtleDB.produceChestPos)
    self.produceGN.unknown = false
    self.treeGNs =
        TUtil:Map(
        turtleDB.treePositions,
        function(treePositionGV)
            return self.tnav.gridMap:GetGridNode(treePositionGV)
        end
    )

    self:FLog("Moving to Produce Chest Position %s", self.produceGN)
    -- go to start positions
    local success = self:NavigateToPosition(self.produceGN.pos)
    if not success then
        error("Could not reach Produce Chest Position")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end
    self:FLog("Moving to Resource Chest Position %s", self.produceGN)
    success = self:NavigateToPosition(self.resourceGN.pos)
    if not success then
        error("Could not reach Resource Chest Position")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end

    self:SetState(RubberTurtle.STATE.DECIDE_ACTION)
end

function RubberTurtle:FETCH_SAPLINGS()
    self:NavigateToPosition(self.resourceGN.pos)
    local success = self:TurnToChest()

    if not success then
        self:Log("Error: Resource Chest not found!")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end

    self:Log("Get Saplings..")
    self:SuckFromChest(CONST.ITEMS.RUBBER_SAPLINGS)
    self:DropItems(self.RESOURCE_CHEST_ITEMS)

    self:SetState(RubberTurtle.STATE.DECIDE_ACTION)
end

---@return GNAV.GridNode? candidateGN
---@return GNAV.GridArea? candidateArea
function RubberTurtle:GetTreePositionCandidate()
    local requiredRadius = 3
    local z = self.tnav.currentGN.pos.z
    self.invalidTreeGNs = self.invalidTreeGNs or {}

    local result =
        self.tnav.gridMap:IterateGridNodes(
        function(gridNode)
            if gridNode:IsEmpty() then
                local sX, sY = self.tnav.gridMap:GetGridSize()
                self:FLog("gridsize: %d/%d", sX, sY)
                self:FLog("Tree Pos? %s", gridNode)
                local inFence = self.tnav.geoFence and self.tnav.geoFence:IsWithin(gridNode)
                self:FLog("- In Fence: %s", inFence)

                if inFence and not TUtil:tContains(self.invalidTreeGNs, gridNode) then
                    local area = self.tnav.gridMap:GetAreaAround(gridNode, requiredRadius)
                    local areaEmpty = area:IsEmpty()
                    local areaInFence = self.tnav.geoFence:IsAreaWithin(area)

                    if areaEmpty and areaInFence then
                        local noTreeNeighbors =
                            TUtil:Every(
                            area.nodeList,
                            function(gn)
                                return not TUtil:tContains(self.treeGNs, gn)
                            end
                        )
                        if noTreeNeighbors then
                            return {gridNode = gridNode, area = area}
                        end
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

    if not result then
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
            local rtData = self.turtleDB.data
            table.insert(rtData.treePositions, candidateGN.pos)
            self:PersistTurtleDB()
            self:SetState(RubberTurtle.STATE.DECIDE_ACTION)
        end
    else
        self:Log("No available tree pos candidate")
        self:SetState(RubberTurtle.STATE.EXIT)
    end
end

function RubberTurtle:REFUEL()
    if not self:Refuel() then
        self:Log("Fetching Fuel..")
        if not self:NavigateToPosition(self.resourceGN.pos) then
            self:Log("Error: Cannot reach Resources")
            self:SetState(RubberTurtle.STATE.EXIT)
            return
        end

        if not self:TurnToChest() then
            self:Log("Error: No Resource Chest Found")
            self:SetState(RubberTurtle.STATE.EXIT)
            return
        end

        if not self:RefuelFromChest() then
            self:DropItems(self.RESOURCE_CHEST_ITEMS)
            self:SetState(RubberTurtle.STATE.REQUEST_FUEL)
            return
        end
    end
end

function RubberTurtle:REQUEST_FUEL()
    repeat
        term.clear()
        term.setCursorPos(1, 1)
        print(f("Please Insert Fuel: %d / %d", turtle.getFuelLevel(), self.minimumFuel))
        os.pullEvent("turtle_inventory")
        local refueled = self:Refuel()
    until refueled
    self:SetState(RubberTurtle.STATE.DECIDE_ACTION)
end

function RubberTurtle:DECIDE_ACTION()
    if turtle.getFuelLevel() < self.minimumFuel then
        self:SetState(RubberTurtle.STATE.REFUEL)
    elseif #self.treeGNs < self.treeCount then
        self:SetState(RubberTurtle.STATE.EXPLORE_TREE_POSITIONS)
    elseif not self:GetInventoryItem(CONST.ITEMS.RUBBER_SAPLINGS) then
        self:SetState(RubberTurtle.STATE.FETCH_SAPLINGS)
    else
        self:SetState(RubberTurtle.STATE.EXIT)
    end
end

return RubberTurtle
