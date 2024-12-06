local GTurtle = require("GCC/GTurtle/gturtle")
local GState = require("GCC/Util/gstate")

---@class GTurtle.RubberTurtle.Options : GTurtle.Base.Options

---@class GTurtle.RubberTurtle : GTurtle.Base
---@overload fun(options: GTurtle.RubberTurtle.Options) : GTurtle.RubberTurtle
local RubberTurtle = GTurtle.Base:extend()

---@param options GTurtle.RubberTurtle.Options
function RubberTurtle:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    self.super.new(self, options)
    self.type = GTurtle.TYPES.RUBBER
end

function RubberTurtle:INIT()
    print("Hello?")
    sleep(2)
    print("Good Bye!")
    self:SetState(GState.STATE.EXIT)
end

return RubberTurtle
