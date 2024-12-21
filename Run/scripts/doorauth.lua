local DoorAuthHost = require("GCC/GAuth/DoorAuth/doorauthhost")
local monitor = peripheral.find("monitor")
term.redirect(monitor)
DoorAuthHost {}:Run()
