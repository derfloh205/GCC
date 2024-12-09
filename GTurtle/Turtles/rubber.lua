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

---@class GTurtle.RubberTurtle : GTurtle.Base
---@overload fun(options: GTurtle.RubberTurtle.Options) : GTurtle.RubberTurtle
local RubberTurtle = GTurtle.Base:extend()

---@class GTurtle.RubberTurtle.STATE : GState.STATE
RubberTurtle.STATE = {
    EXPLORE_WORK_FIELD = "EXPLORE_WORK_FIELD"
}
TUtil:Inject(RubberTurtle.STATE, GState.STATE)

---@param options GTurtle.RubberTurtle.Options
function RubberTurtle:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    self.super.new(self, options)
    self.type = GTurtle.TYPES.RUBBER
    ---@type GTurtle.TurtleData.Rubber
    self.turtleData = self.turtleData
end

function RubberTurtle:INIT()
    self:FLog("Initiating Rubber Turtle: %s", self.name)
    local rtData = self.turtleData.data

    if not rtData.produceChestPos or not rtData.resourceChestPos then
        rtData.resourceChestPos = TermUtil:ReadVector("Resource Chest Position?")
        rtData.produceChestPos = TermUtil:ReadVector("Produce Chest Position?")
        self:WriteTurtleData()
    else
        self:Log("Loading Data from File:")
        self:FLog("Resource Chest Pos: %s", rtData.resourceChestPos)
        self:FLog("Produce Chest Pos: %s", rtData.produceChestPos)
    end

    self.resourceGN = self.tnav.gridMap:GetGridNode(rtData.resourceChestPos)
    self.resourceGN.unknown = false
    self.produceGN = self.tnav.gridMap:GetGridNode(rtData.produceChestPos)
    self.produceGN.unknown = false

    self:SetState(RubberTurtle.STATE.EXPLORE_WORK_FIELD)
end

function RubberTurtle:EXPLORE_WORK_FIELD()
    self:NavigateToPosition(self.resourceGN.pos)
    self:NavigateToPosition(self.produceGN.pos)
    repeat
        local neighborGNs = self.tnav:GetNeighbors(true, true, true)
        if neighborGNs[1] then
            self:NavigateToPosition(neighborGNs[1].pos)
        end
    until #neighborGNs == 0

    self:SetState(RubberTurtle.STATE.EXIT)
end

return RubberTurtle
