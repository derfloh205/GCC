local DoorAuthHost = require("GCC/GAuth/DoorAuth/doorauthhost")
local monitor = peripheral.find("monitor")
monitor.setTextScale(3)
term.redirect(monitor)
DoorAuthHost {
    log = false,
    clearLog = true,
    logFile = "doorauthhost.log"
}:Run()
