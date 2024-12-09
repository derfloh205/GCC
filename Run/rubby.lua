local RubberTurtle = require("GCC/GTurtle/Turtles/rubber")

RubberTurtle {
    name = "Rubby",
    minimumFuel = 100,
    log = true,
    clearLog = true,
    visualizeGridOnMove = true,
    treeCount = 1,
    cacheGrid = true
}:Run()
