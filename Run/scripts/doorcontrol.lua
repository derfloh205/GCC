local DoorController = require("GCC/GNet/DoorControl/doorcontroller")

DoorController {
    log = true,
    clearLog = true,
    logFile = "doorcontrol.log"
}:Run()
