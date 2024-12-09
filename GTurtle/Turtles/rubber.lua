local GTurtle = require("GCC/GTurtle/gturtle")
local GState = require("GCC/Util/gstate")
local TUtil = require("GCC/Util/tutil")
local TermUtil = require("GCC/Util/termutil")
local FUtil = require("GCC/Util/futil")
local SUtil = require("GCC/Util/sutil")
local VUtil = require("GCC/Util/vutil")
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

---@param options GTurtle.RubberTurtle.Options
function RubberTurtle:new(options)
    options = options or {}
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
    local success = self:NavigateToPosition(self.resourceGN.pos)
    self:FLog("Navigate To Resource Chest:%s", success)
    -- search for chest
    local neighbors = self.tnav:GetNeighbors(true)
    local chestGNs =
        TUtil:Filter(
        neighbors,
        function(gn)
            return gn:IsChest()
        end
    )
    if not chestGNs[1] then
        -- dance once to scan surroundings
        self:ExecuteMovement("RRRR")
        chestGNs =
            TUtil:Filter(
            neighbors,
            function(gn)
                return gn:IsChest()
            end
        )
    end

    local chestGN = chestGNs[1]

    -- if still nothing here then user lied to us!
    if not chestGN then
        self:Log("Error: Resource Chest not found!")
        self:SetState(RubberTurtle.STATE.EXIT)
        return
    end

    -- otherwise fetch saplings..
    self:Log("Fetching Saplings..")
    self:SetState(RubberTurtle.STATE.EXIT)
end

function RubberTurtle:EXPLORE_TREE_POSITIONS()
    return false
end

function RubberTurtle:DECIDE_ACTION()
    -- if no rubber sapling in inventory - fetch from resource chest
    if not self:GetInventoryItem("ic2:blockrubsapling") then
        self:SetState(RubberTurtle.STATE.FETCH_SAPLINGS)
    elseif #self.treeGNs < self.treeCount then
        self:SetState(RubberTurtle.STATE.EXPLORE_TREE_POSITIONS)
    end

    self:SetState(RubberTurtle.STATE.EXIT)
end

return RubberTurtle
