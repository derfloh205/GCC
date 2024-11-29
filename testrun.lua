local GTurtle = require("GTurtle")

local RT =
    GTurtle.Rubber {
    name = "Rubber#1",
    minimumFuel = 100,
    log = true
}

RT:Refuel()
RT:VisualizeGrid()
RT:Move("F")
RT:VisualizeGrid()
RT:Turn("R")
RT:VisualizeGrid()
RT:Move("F")
RT:VisualizeGrid()
RT:Turn("L")
RT:VisualizeGrid()
RT:Move("F")
RT:VisualizeGrid()
RT:Move("F")
