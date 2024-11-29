local GTurtle = require("GTurtle")
local monitor = peripheral.find("monitor")
term.redirect(monitor)
GTurtle.GNet.TurtleHost {}:StartServer()
