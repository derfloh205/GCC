local GTurtle = require("GCC/GTurtle/gturtle")
local GState = require("GCC/Util/gstate")
local TUtil = require("GCC/Util/tutil")
local TermUtil = require("GCC/Util/termutil")
local FUtil = require("GCC/Util/futil")
local SUtil = require("GCC/Util/sutil")
local f = string.format

---@class GTurtle.RubberTurtle.RTData
---@field saplingChestPos Vector
---@field produceChestPos Vector

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
    self.rtFile = f("%d_rt.json", self.id)
    ---@type GTurtle.RubberTurtle.RTData
    self.rtData = nil
end

function RubberTurtle:INIT()
    self:FLog("Initiating Rubber Turtle: %s", self.name)
    if fs.exists(self.rtFile) then
        local confirmed = TermUtil:ReadConfirmation("Load Positions from Cache?")
        if confirmed then
            local saplingChestPos = TermUtil:ReadVector("Sapling Chest Position?")
            print("saplingChestPos: " .. tostring(saplingChestPos))
        else
            self.rtData = FUtil:LoadJSON(self.rtFile)
            if not self.rtData then
                print("Could not load data from " .. self.rtFile)
                self:SetState(RubberTurtle.STATE.EXIT)
            else
                self:SetState(self.STATE.SEARCH_TREE)
            end
        end
    end
end

function RubberTurtle:SEARCH_TREE()
    self:SetState(RubberTurtle.STATE.EXIT)
end

return RubberTurtle
