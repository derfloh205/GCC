local GTurtle = require("GTurtle")

local RT =
    GTurtle.Rubber {
    name = "Rubber#1",
    minimumFuel = 100,
    log = true,
    visualizeGridOnMove = true
}

RT:Refuel()
RT:ExecuteMovement("FRFLFFLF")
