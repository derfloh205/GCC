local GTurtle = require("GCC/GTurtle/gturtle")

local RT =
    GTurtle.Rubber {
    name = "Rubby",
    minimumFuel = 100,
    log = true,
    clearLog = true,
    visualizeGridOnMove = true
}

RT:Refuel()
RT:ExecuteMovement("FRFLFFLFFRFLFFRFFR")
--RT:ExecuteMovement("FLLLLB")
--RT.tnav:LogPos()
RT:NavigateToInitialPosition()
