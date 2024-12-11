local GUI = require("GCC/GUI/gui")
local monitor = peripheral.find("monitor")

monitor.setTextScale(1)

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
    sizeX = 6,
    sizeY = 6,
    x = 15,
    y = 15,
    monitor = monitor,
    pixels = {
        {x = 1, y = 1, c = colors.red},
        {x = 2, y = 1, c = colors.green},
        {x = 3, y = 1, c = colors.magenta},
        {x = 4, y = 1, c = colors.blue},
        {x = 5, y = 1, c = colors.cyan},
        {x = 6, y = 1, c = colors.pink},
        {x = 6, y = 2, c = colors.red},
        {x = 5, y = 2, c = colors.green},
        {x = 4, y = 2, c = colors.magenta},
        {x = 3, y = 2, c = colors.blue},
        {x = 2, y = 2, c = colors.cyan},
        {x = 1, y = 2, c = colors.pink}
    }
}

UI:Run()
