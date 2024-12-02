local GTurtle = require("GTurtle.gturtle")
local monitor = peripheral.find("monitor")
term.redirect(monitor)
GTurtle.GNet.TurtleHost {}:StartServer()
