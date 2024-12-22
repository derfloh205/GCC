local DoorController = require("GCC/GNet/DoorControl/doorcontroller")

DoorController {
    log = false,
    clearLog = true,
    logFile = "doorcontrol.log"
}:Run()
