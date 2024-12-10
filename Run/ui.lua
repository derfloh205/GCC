local GUI = require("GCC/GUI/gui")
local monitor = peripheral.find("monitor")

local UI =
    GUI.Frontend {
    touchscreen = true,
    monitor = monitor
}

local testButton =
    GUI.Button {
    parent = monitor,
    frontend = UI,
    posX = 10,
    posY = 10,
    sizeX = 20,
    sizeY = 10,
    label = "Hello World",
    clickCallback = function(self)
        term.native().write("CLICKED")
    end
}

local testButton2 =
    GUI.Button {
    parent = monitor,
    frontend = UI,
    posX = 10,
    posY = 30,
    sizeX = 20,
    sizeY = 10,
    label = "Hello World2",
    clickCallback = function(self)
        term.native().write("CLICKED2")
    end
}

UI:Run()
