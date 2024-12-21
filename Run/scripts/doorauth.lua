local DoorAuthHost = require("GCC/GAuth/DoorAuth/doorauthhost")
local monitor = peripheral.find("monitor")
term.redirect(monitor)
DoorAuthHost {
    logFile = "doorauthhost.log",
    log = true,
    clearLog = true
}:Run()
