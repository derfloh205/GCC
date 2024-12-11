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
    posX = 5,
    posY = 5,
    sizeX = 9,
    sizeY = 2,
    label = "Hello One",
    backgroundColor = colors.white,
    textColor = colors.red,
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
    sizeX = 9,
    sizeY = 2,
    label = "Hello Two",
    backgroundColor = colors.green,
    textColor = colors.magenta,
    clickCallback = function(self)
        term.native().write("TWO")
    end
}

local icon =
    GUI.Icon {
    parent = monitor,
    sizeX = 2,
    sizeY = 2,
    x = 15,
    y = 15,
    monitor = monitor,
    pixels = {
        {x = 1, y = 1, c = colors.red},
        {x = 2, y = 2, c = colors.cyan},
        {x = 3, y = 3, c = colors.magenta},
        {x = 4, y = 4, c = colors.purple}
    }
}

UI:Run()
