local TNet = require("GCC/GTurtle/tnet")
local monitor = peripheral.find("monitor")

if monitor then
    term.redirect(monitor)
end

local THost =
    TNet.TurtleHost {
    log = true,
    clearLog = true
}

THost:Run()
