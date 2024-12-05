local GTurtle = require("GCC/GTurtle/gturtle")

local BaseTurtle =
    GTurtle.Base {
    name = "Testy",
    minimumFuel = 100,
    log = true,
    clearLog = true,
    visualizeGridOnMove = true
}

BaseTurtle:Refuel()
--BaseTurtle:ExecuteMovement("FRFLFFLFFRFLFFRFFR")
--BaseTurtle:ExecuteMovement("FLLLLB")
--BaseTurtle.tnav:LogPos()
local goalPos = vector.new(263, -32, 46)
BaseTurtle:NavigateToPosition(goalPos)
