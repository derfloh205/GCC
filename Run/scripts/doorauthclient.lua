local DoorAuthClient = require("GCC/GAuth/DoorAuth/doorauthclient")

DoorAuthClient {
    log = true,
    clearLog = true,
    logFile = "doorauthclient.log"
}:Run()
