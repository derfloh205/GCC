local DoorAuthClient = require("GCC/GAuth/DoorAuth/doorauthclient")

DoorAuthClient {
    log = false,
    clearLog = true,
    logFile = "doorauthclient.log"
}:Run()
