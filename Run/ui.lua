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
    label = "Hello One",
    backgroundColor = colors.write,
    clickCallback = function(self)
        term.native().write("ONE")
    end
}

local testButton2 =
    GUI.Button {
    parent = monitor,
    frontend = UI,
    posX = 5,
    posY = 10,
    sizeX = 20,
    sizeY = 10,
    label = "Hello Two",
    backgroundColor = colors.green,
    clickCallback = function(self)
        term.native().write("TWO")
    end
}

UI:Run()
