local GTurtle = require("GCC/GTurtle/gturtle")
local GVector = require("GCC/GNav/gvector")

local BaseTurtle =
    GTurtle.Base {
    name = "Navy",
    minimumFuel = 100,
    log = true,
    clearLog = true,
    visualizeGridOnMove = true
}

--BaseTurtle:ExecuteMovement("FRFLFFLFFRFLFFRFFR")
--BaseTurtle:ExecuteMovement("FLLLLB")
--BaseTurtle.tnav:LogPos()
local goalPos = GVector(263, -32, 46)

local success = BaseTurtle:NavigateToPosition(goalPos)
if success then
    BaseTurtle:NavigateToInitialPosition()
end
