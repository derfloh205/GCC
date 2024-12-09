local GTurtle = require("GCC/GTurtle/gturtle")
local GState = require("GCC/Util/gstate")
local TUtil = require("GCC/Util/tutil")
local TermUtil = require("GCC/Util/termutil")
local FUtil = require("GCC/Util/futil")
local SUtil = require("GCC/Util/sutil")
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
    SEARCH_TREE = "SEARCH_TREE"
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

    self:SetState(RubberTurtle.STATE.SEARCH_TREE)
end

function RubberTurtle:SEARCH_TREE()
    self:SetState(RubberTurtle.STATE.EXIT)
end

return RubberTurtle
