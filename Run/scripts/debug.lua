local RubberTurtle = require("GCC/GTurtle/Turtles/rubber")
--TODO: nice Debug console with live log and UI !
local T =
    RubberTurtle {
    log = true,
    clearLog = true,
    minimumFuel = 100,
    --visualizeGridOnMove = true,
    name = "Buggy"
}

_G["self"] = T
_G["tnav"] = T.tnav
_G["gm"] = T.tnav.gridMap

shell.run("lua")
