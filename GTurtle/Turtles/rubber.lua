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

RubberTurtle.MAX_GROW_TIME = 60

RubberTurtle.RESIN_FACE_MAP = {
    ["north"] = GNAV.HEAD.N,
    ["east"] = GNAV.HEAD.E,
    ["south"] = GNAV.HEAD.S,
    ["west"] = GNAV.HEAD.W
}

--[[
    INIT (-> INIT_TREE_POSITIONS) -> FETCH_RESOURCES -> DROP_PRODUCTS -> WAIT_FOR_TREES_GROWING -> FARM_TREES -> FETCH_RESOURCES
--]]
---@class GTurtle.RubberTurtle.STATE : GState.STATE
RubberTurtle.STATE = {
    INIT_TREE_POSITIONS = "INIT_TREE_POSITIONS",
    FETCH_RESOURCES = "FETCH_RESOURCES",
    DROP_PRODUCTS = "DROP_PRODUCTS",
    FARM_TREES = "FARM_TREES",
    WAIT_FOR_TREES_GROWING = "WAIT_FOR_TREES_GROWING"
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
    options.avoidAllBlocks = false
    options.fuelWhitelist = {CONST.ITEMS.RUBBER_WOOD, CONST.ITEMS.COAL, CONST.ITEMS.LAVA_BUCKET}
    options.digWhitelist = {CONST.ITEMS.RUBBER_WOOD, CONST.ITEMS.RUBBER_LEAVES}
    ---@diagnostic disable-next-line: redundant-parameter
    self.super.new(self, options)
    self.type = GTurtle.TYPES.RUBBER
    ---@type GTurtle.TurtleDB.Rubber
    self.turtleDB = self.turtleDB
    self.treeCount = 1
    ---@type table<GNAV.GridNode, number>
    self.saplingPlantTimes = {}
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
    self:FLogFeed("Initiating %s", self.name)
    local turtleDB = self.turtleDB.data --[[@as GTurtle.TurtleDB.Rubber.Data]]
    if not turtleDB.resourceChestPos then
        self:LogFeed("Requesting Position..")
        turtleDB.resourceChestPos = TermUtil:ReadGVector("Resource Chest Position?")
    end
    if not turtleDB.produceChestPos then
        self:LogFeed("Requesting Position..")
        turtleDB.produceChestPos = TermUtil:ReadGVector("Produce Chest Position?")
    end

    if not turtleDB.fenceCorners or #turtleDB.fenceCorners < 4 then
        self:LogFeed("Requesting GeoFence..")
        turtleDB.fenceCorners = turtleDB.fenceCorners or {}
        turtleDB.fenceCorners[1] = TermUtil:ReadGVector("Fence #1")
        turtleDB.fenceCorners[2] = TermUtil:ReadGVector("Fence #2")
        turtleDB.fenceCorners[3] = TermUtil:ReadGVector("Fence #3")
        turtleDB.fenceCorners[4] = TermUtil:ReadGVector("Fence #4")
    end

    if not turtleDB.treeCount then
        self:LogFeed("Requesting Tree Count..")
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

    self.tnav:AddAvoidGNList(self.treeGNs)

    -- go to start
    if not self:NavigateToPosition(self.resourceGN.pos) then
        self:LogFeed("NavError: Resources")
        self:Log("Could not reach resource chest")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end

    if #self.treeGNs < self.treeCount then
        self:SetState(RubberTurtle.STATE.INIT_TREE_POSITIONS)
        return
    end

    self:SetState(RubberTurtle.STATE.FETCH_RESOURCES)
end

function RubberTurtle:FETCH_RESOURCES()
    self:LogFeed("Fetching Resources..")
    local response = self:NavigateToPosition(self.resourceGN.pos)
    if response ~= GTurtle.RETURN_CODE.SUCCESS then
        self:LogFeed("NavError: Resources")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end

    response = self:TurnToChest()
    if response ~= GTurtle.RETURN_CODE.SUCCESS then
        self:LogFeed("ChestError: Resources")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end

    self:SuckEverythingFromChest()
    self:SetState(RubberTurtle.STATE.DROP_PRODUCTS)
end

function RubberTurtle:DROP_PRODUCTS()
    self:LogFeed("Dropping Products..")
    if
        not self:GetInventoryItem(CONST.ITEMS.RESIN) and not self:GetInventoryItem(CONST.ITEMS.RUBBER_WOOD) and
            not self:GetInventoryItem(CONST.ITEMS.RUBBER_LEAVES)
     then
        self:SetState(RubberTurtle.STATE.WAIT_FOR_TREES_GROWING)
        return
    end

    if self:NavigateToPosition(self.produceGN.pos) ~= GTurtle.RETURN_CODE.SUCCESS then
        self:LogFeed("NavError: Products")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end

    if not self:TurnToChest() then
        self:LogFeed("ChestError: Products")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end

    self:DropItems(self.PRODUCE_CHEST_ITEMS)
    self:SetState(RubberTurtle.STATE.WAIT_FOR_TREES_GROWING)
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
    local rtData = self.turtleDB.data
    self:LogFeed("Init Tree Positions..")
    while #self.treeGNs < self.treeCount do
        local candidateGN, candidateArea = self:GetTreePositionCandidate()

        if candidateGN and candidateArea then
            self:LogFeed("Visit Candidate..")
            self:FLog("Tree Candidate Position %s", tostring(candidateGN and candidateGN.pos))
            local response = self:NavigateToPosition(candidateGN.pos, true)
            if response == GTurtle.RETURN_CODE.SUCCESS then
                self:Log("Arrived at Candidate, Navigate to corners")
                self:LogFeed("Checking Area..")
                local areaCorners = candidateArea:GetCorners(candidateGN.pos.z)
                -- navigate to area corners to inspect
                local cornersValid = true
                for _, cornerGN in ipairs(areaCorners) do
                    if self:NavigateToPosition(cornerGN.pos, true) ~= GTurtle.RETURN_CODE.SUCCESS then
                        cornersValid = false
                        self:Log("Not able to inspect tree area")
                        self:LogFeed("Invalid Area..")
                        table.insert(self.invalidTreeGNs, candidateGN)
                        break
                    end
                end
                if cornersValid and candidateArea:IsEmpty() then
                    self:FLog("Viable Tree Position Found: %s", candidateGN)
                    self:LogFeed("Tree Position Found!")
                    table.insert(self.treeGNs, candidateGN)
                    table.insert(rtData.treePositions, candidateGN.pos)
                    self.tnav:AddAvoidGN(candidateGN)
                    self:PersistTurtleDB()
                end
            else
                self:Log("Not able to navigate to tree pos")
                self:LogFeed("Not Reachable..")
                table.insert(self.invalidTreeGNs, candidateGN)
            end
        else
            self:Log("No available tree pos candidate")
            rtData.treeCount = #self.treeGNs
            if rtData.treeCount == 0 then
                self:Log("No viable tree positions found")
                self:LogFeed("No Valid Tree Positions..")
                self:SetState(RubberTurtle.STATE.EXIT)
                return
            else
                self:FLog("Viable Tree Count Found: %d / %d", rtData.treeCount, self.treeCount)
                self:FLogFeed("Tree Positions: %d", rtData.treeCount)
                rtData:PersistTurtleDB()
                self.treeCount = rtData.treeCount
                break
            end
        end
    end

    self:SetState(RubberTurtle.STATE.FETCH_RESOURCES)
end

function RubberTurtle:PlantSapling(treeGN)
    if not self:GetInventoryItem(CONST.ITEMS.RUBBER_SAPLINGS) then
        return
    end

    if not treeGN:IsEmpty() then
        return
    end

    self:LogFeed("Placing Sapling..")
    self:PlaceItem(CONST.ITEMS.RUBBER_SAPLINGS)
    self:SetSaplingPlantTime(treeGN)
end

function RubberTurtle:FertilizeSapling(treeGN)
    if not treeGN:IsItem(CONST.ITEMS.RUBBER_SAPLINGS) then
        return
    end

    while self:GetInventoryItem(CONST.ITEMS.BONE_MEAL) and not treeGN:IsItem(CONST.ITEMS.RUBBER_WOOD) do
        self:LogFeed("Fertilizing..")
        self:UseItem(CONST.ITEMS.BONE_MEAL)
    end

    if treeGN:IsItem(CONST.ITEMS.RUBBER_WOOD) then
        self:LogFeed("Tree!")
        self:ResetSaplingPlantTime(treeGN)
    else
        self:LogFeed("No Tree Yet..")
        self:SetSaplingPlantTime(treeGN)
    end
end

---@param treeGN GNAV.GridNode
function RubberTurtle:NurtureTree(treeGN)
    self:LogFeed("Nurturing..")
    self:PlantSapling(treeGN)
    self:FertilizeSapling(treeGN)
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

---@param treeBaseGN GNAV.GridNode
---@return boolean harvestedSomething
function RubberTurtle:HarvestTree(treeBaseGN)
    self:LogFeed("Harvesting..")
    local startHeight = treeBaseGN.pos.z
    local maxHeight = startHeight + 10
    local harvestedSomething = false
    repeat
        local woodGN = self.tnav.currentGN:GetRelativeNode(self.tnav.head, GNAV.DIR.F)
        if not woodGN:IsItem(CONST.ITEMS.RUBBER_WOOD) then
            self:LogFeed("No Wood to Harvest..")
            break
        end

        harvestedSomething = true

        local resinHead = self:GetResinHead(woodGN)
        if resinHead then
            self:FLogFeed("Resin: %s", resinHead)
            local harvestGN = woodGN:GetRelativeNode(resinHead, GNAV.DIR.F)
            if not self:NavigateToPosition(harvestGN.pos) then
                self:LogFeed("Resin Unreachable..")
                break
            end
            self:TurnTo(CONST.ITEMS.RUBBER_WOOD)
            self:LogFeed("Harvesting Resin..")
            local usedTreeTap = false
            repeat
                usedTreeTap = self:UseItem(CONST.TOOLS.ELECTRIC_TREE_TAP) or self:UseItem(CONST.TOOLS.TREE_TAP)
                if not usedTreeTap then
                    self:LogFeed("Requesting Tree Tap..")
                    self:RequestOneOfItem(
                        {CONST.TOOLS.ELECTRIC_TREE_TAP, CONST.TOOLS.TREE_TAP},
                        "Tree Tap required.. Please insert!"
                    )
                end
            until usedTreeTap
            self:CollectDrops()
        end

        self:LogFeed("Harvesting Wood..")
        self:Dig("F")
        self:LogFeed("Climbing..")
        self:Dig("U") -- only leaves and wood
        local climbResponse = self:Move("U")
    until maxHeight <= self.tnav.currentGN.pos.z or climbResponse == GTurtle.RETURN_CODE.BLOCKED

    return harvestedSomething
end

---@param treeGN GNAV.GridNode
function RubberTurtle:SetSaplingPlantTime(treeGN)
    self.saplingPlantTimes[treeGN] = os.epoch("local")
end

function RubberTurtle:ResetSaplingPlantTime(treeGN)
    self.saplingPlantTimes[treeGN] = nil
end

---@return number? seconds nil = no sapling planted
function RubberTurtle:GetSaplingGrowSeconds(treeGN)
    if not self.saplingPlantTimes[treeGN] then
        return
    end
    return (os.epoch("local") - self.saplingPlantTimes[treeGN]) / 1000
end

function RubberTurtle:WAIT_FOR_TREES_GROWING()
    local saplingGrowTimes =
        TUtil:Map(
        self.treeGNs,
        function(treeGN)
            return self:GetSaplingGrowSeconds(treeGN)
        end
    )

    if #saplingGrowTimes == 0 then
        self:SetState(RubberTurtle.STATE.FARM_TREES)
        return
    end

    local maxGrowTime = math.max(table.unpack(saplingGrowTimes))

    if maxGrowTime < self.MAX_GROW_TIME then
        self.tNetClient:SendTurtleDataUpdate()
        self:FLogFeed("Awaiting Grow: %d", self.MAX_GROW_TIME - maxGrowTime)
        sleep(1) -- yield back to state scheduler
        return
    end
    self:SetState(RubberTurtle.STATE.FARM_TREES)
end

function RubberTurtle:FARM_TREES()
    self:LogFeed("Farming Trees..")
    for _, treeGN in ipairs(self.treeGNs) do
        -- get block in front of tree
        local targetGN = treeGN:GetClosestNeighbor(self.tnav.currentGN, true)

        if not targetGN then
            self:LogFeed("NavError: Tree")
            self:SetState(RubberTurtle.STATE.EXIT)
            return
        end

        local success = self:NavigateToPosition(targetGN.pos)
        if success ~= GTurtle.RETURN_CODE.SUCCESS then
            self:LogFeed("NavError: Tree")
            self:SetState(RubberTurtle.STATE.EXIT)
            return
        end
        self:LogFeed("Turning to Tree..")
        -- turn to tree pos
        self:TurnToHead(self.tnav.currentGN:GetRelativeHeading(treeGN))
        self:NurtureTree(treeGN)
        local harvestedSomething = self:HarvestTree(treeGN)
        -- climb down
        repeat
            self:LogFeed("Climbing Down..")
        until self:Move("D") == GTurtle.RETURN_CODE.BLOCKED
        if harvestedSomething then
            -- collect possible drops in area (navigate to each node except the middle one)
            local area = self.tnav.gridMap:GetAreaAround(treeGN, 3)
            self:LogFeed("Searching for Loot..")
            local searchNodes =
                TUtil:Filter(
                area.nodeList,
                function(gn)
                    return gn ~= treeGN
                end
            )
            for _, gn in ipairs(searchNodes) do
                self:NavigateToPosition(gn.pos)
                self:CollectDrops()
            end
        end
    end

    -- Repeat Cycle
    self:SetState(RubberTurtle.STATE.FETCH_RESOURCES)
end

return RubberTurtle
