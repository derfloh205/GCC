local GTurtle = require("GCC/GTurtle/gturtle")
--TODO: nice Debug console with live log and UI !
local T =
    GTurtle.Base {
    log = true,
    clearLog = true,
    visualizeGridOnMove = true,
    name = "Buggy"
}

_G["self"] = T
_G["tnav"] = T.tnav
_G["gm"] = T.tnav.gridMap
