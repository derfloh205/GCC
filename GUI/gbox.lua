local pixelbox = require("GCC/Lib/pixelbox_lite")
local GWindow = require("GCC/GUI/gwindow")

---@class GBox.Pixel
---@field x number
---@field y number
---@field c number

---@class GBox.Options : GWindow.Options

---@class GBox : GWindow
---@overload fun(options:GBox.Options) : GBox
local GBox = GWindow:extend()

---@param options GBox.Options
function GBox:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    GBox.super.new(self, options)

    self.box = pixelbox.new(self.window)
end

---@param pixels GBox.Pixel[]
function GBox:Draw(pixels)
    for _, pixel in ipairs(pixels) do
        self.box.canvas[pixel.x][pixel.y] = pixel.c
    end
    self.box:render()
end

return GBox
