local GTurtle = require("GCC/GTurtle/gturtle")
local GState = require("GCC/Util/gstate")
local GNAV = require("GCC/GNav/gnav")
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

RubberTurtle.RESIN_FACE_MAP = {
    ["north"] = GNAV.HEAD.N,
    ["east"] = GNAV.HEAD.E,
    ["south"] = GNAV.HEAD.S,
    ["west"] = GNAV.HEAD.W
}

---@class GTurtle.RubberTurtle.STATE : GState.STATE
RubberTurtle.STATE = {
    INIT_TREE_POSITIONS = "INIT_TREE_POSITIONS",
    FETCH_SAPLINGS = "FETCH_SAPLINGS",
    SEARCH_TREE = "",
    DECIDE_ACTION = "DECIDE_ACTION",
    REFUEL = "REFUEL",
    DROP_PRODUCTS = "DROP_PRODUCTS",
    TREE_FARMING_PROCEDURE = "TREE_FARMING_PROCEDURE"
}
TUtil:Inject(RubberTurtle.STATE, GState.STATE)

RubberTurtle.PRODUCE_CHEST_ITEMS = {
    CONST.ITEMS.RUBBER_WOOD,
    CONST.ITEMS.RESIN,
    CONST.ITEMS.RUBBER_LEAVES
}

---@param options GTurtle.RubberTurtle.Options
function RubberTurtle:new(options)
    options = options or {}
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
    if success ~= GTurtle.RETURN_CODE.SUCCESS then
        error("Could not reach Produce Chest Position")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end
    self:FLog("Moving to Resource Chest Position %s", self.produceGN)
    success = self:NavigateToPosition(self.resourceGN.pos)
    if success ~= GTurtle.RETURN_CODE.SUCCESS then
        error("Could not reach Resource Chest Position")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end

    self:SetState(RubberTurtle.STATE.DECIDE_ACTION)
end

function RubberTurtle:FetchResources()
    local response = self:NavigateToPosition(self.resourceGN.pos)
    if response ~= GTurtle.RETURN_CODE.SUCCESS then
        self:Log("Error: Resource Chest not found!")
        return response
    end

    response = self:TurnToChest()
    if response ~= GTurtle.RETURN_CODE.SUCCESS then
        self:Log("Error: Resource Chest not found!")
        return GTurtle.RETURN_CODE.FAILURE
    end

    self:SuckEverythingFromChest()
    return GTurtle.RETURN_CODE.SUCCESS
end

function RubberTurtle:DROP_PRODUCTS()
    if self:NavigateToPosition(self.produceGN.pos) ~= GTurtle.RETURN_CODE.SUCCESS then
        self:Log("Could not reach produce chest")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end

    if not self:TurnToChest() then
        self:Log("Could not find produce chest")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end

    self:DropItems(self.PRODUCE_CHEST_ITEMS)
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

function RubberTurtle:INIT_TREE_POSITIONS()
    local candidateGN, candidateArea = self:GetTreePositionCandidate()

    if candidateGN and candidateArea then
        self:FLog("Tree Candidate Position %s", tostring(candidateGN and candidateGN.pos))
        local success = self:NavigateToPosition(candidateGN.pos, true)
        if success ~= GTurtle.RETURN_CODE.SUCCESS then
            self:Log("Not able to navigate to tree pos")
            table.insert(self.invalidTreeGNs, candidateGN)
            return
        end
        self:Log("Arrived at Candidate, Navigate to corners")
        local areaCorners = candidateArea:GetCorners(candidateGN.pos.z)
        -- navigate to area corners to inspect
        for _, cornerGN in ipairs(areaCorners) do
            local success = self:NavigateToPosition(cornerGN.pos, true)
            if success ~= GTurtle.RETURN_CODE.SUCCESS then
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
        local navResponse = self:NavigateToPosition(self.resourceGN.pos)
        if navResponse == GTurtle.RETURN_CODE.SUCCESS then
            if self:FetchResources() == GTurtle.RETURN_CODE.SUCCESS then
                if not self:Refuel() then
                    self:RequestFuel()
                end
                self:SetState(RubberTurtle.STATE.DECIDE_ACTION)
                return
            end
        end

        self:Log("Could not reach resource chest")
        self:SetState(RubberTurtle.STATE.EXIT)
    end
end

---@param treeGN GNAV.GridNode
function RubberTurtle:NurtureTree(treeGN)
    if treeGN:IsEmpty() and self:GetInventoryItem(CONST.ITEMS.RUBBER_SAPLINGS) then
        self:PlaceItem(CONST.ITEMS.RUBBER_SAPLINGS)
    end

    if treeGN:IsItem(CONST.ITEMS.RUBBER_SAPLINGS) and self:GetInventoryItem(CONST.ITEMS.BONE_MEAL) then
        self:UseItem(CONST.ITEMS.BONE_MEAL)
    end
end

---@param treeGN GNAV.GridNode
---@return GNAV.HEAD?
function RubberTurtle:GetResinHead(treeGN)
    if not treeGN:IsItem(CONST.ITEMS.RUBBER_WOOD) then
        return
    end
    local state = treeGN.blockData.state --[[@as BlockState.RubberWood]]
    if state.resin and state.collectable then
        local facing = state.resinfacing
        return self.RESIN_FACE_MAP[facing]
    end
end

---@param treeGN GNAV.GridNode
function RubberTurtle:HarvestTree(treeGN)
    self:Log("Harvesting Tree")
    if not treeGN:IsItem(CONST.ITEMS.RUBBER_WOOD) then
        return
    end
    local resinHead = self:GetResinHead(treeGN)
    if not resinHead then
        return
    end
    self:Log("Found Resin. Navigating to Harvest Position")
    local harvestGN = treeGN:GetRelativeNode(resinHead, GNAV.DIR.F)
    if not self:NavigateToPosition(harvestGN.pos) then
        self:Log("Could not reach harvest position")
        return
    end
    self:Log("Harvesting Resin")
    if not self:UseItem(CONST.TOOLS.ELECTRIC_TREE_TAP) then
        if not self:UseItem(CONST.TOOLS.TREE_TAP) then
            self:Log("Could not harvest resin: no tree tap")
            self:RequestOneOfItem(
                {CONST.TOOLS.ELECTRIC_TREE_TAP, CONST.TOOLS.TREE_TAP},
                "Tree Tap required.. Please insert!"
            )
        end
    end

    self:Log("Harvesting Wood..")
    self:Dig("F")
    self:Move("U")
    self:Log("Climbing Up..")
    self:HarvestTree(treeGN)
end

function RubberTurtle:TREE_FARMING_PROCEDURE()
    -- go to each tree, if there is wood, farm it, if not place a sapling, if there is a sapling use bone meal
    for _, treeGN in ipairs(self.treeGNs) do
        -- get block in front of tree
        local targetGN = treeGN:GetClosestNeighbor(self.tnav.currentGN, true)

        if not targetGN then
            self:Log("Could not find target for tree")
            self:SetState(RubberTurtle.STATE.EXIT)
            return
        end

        local success = self:NavigateToPosition(targetGN.pos)
        if success ~= GTurtle.RETURN_CODE.SUCCESS then
            self:Log("Could not reach adjacent tree position")
            self:SetState(RubberTurtle.STATE.EXIT)
            return
        end

        -- turn to tree pos
        self:TurnToHead(self.tnav.currentGN:GetRelativeHeading(treeGN))
        self:NurtureTree(treeGN)
        self:HarvestTree(treeGN)
        -- climb down
        self:Log("Climbing Down..")
        repeat
        until self:Move("D") == GTurtle.RETURN_CODE.BLOCKED
    end
end

function RubberTurtle:DECIDE_ACTION()
    if not self:HasMinimumFuel() then
        self:SetState(RubberTurtle.STATE.REFUEL)
    elseif #self.treeGNs < self.treeCount then
        self:SetState(RubberTurtle.STATE.INIT_TREE_POSITIONS)
    elseif self:GetInventoryItem(CONST.ITEMS.RESIN) or self:GetInventoryItem(CONST.ITEMS.RUBBER_WOOD) then
        self:SetState(RubberTurtle.STATE.DROP_PRODUCTS)
    else
        self:SetState(RubberTurtle.STATE.TREE_FARMING_PROCEDURE)
    end
end

return RubberTurtle
