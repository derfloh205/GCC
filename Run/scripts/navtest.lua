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

if BaseTurtle:NavigateToPosition(goalPos) == GTurtle.RETURN_CODE.SUCCESS then
    if BaseTurtle:NavigateToInitialPosition() == GTurtle.RETURN_CODE.SUCCESS then
        BaseTurtle:Log("Success")
    else
        BaseTurtle:Log("Failed to return to initial position")
    end
end
