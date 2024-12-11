local pixelbox = require("GCC/Lib/bixelbox_lite")
local GWindow = require("GCC/GUI/gwindow")

---@class GBox.Pixel
---@field x number
---@field y number
---@field c number

---@class GBox.Options : GWindow.Options
---@field sizeX number pixels (multiple of 2)
---@field sizeY number pixels (multiple of 3)

---@class GBox : GWindow
---@overload fun(options:GBox.Options) : GBox
local GBox = GWindow:extend()

---@param options GBox.Options
function GBox:new(options)
    options = options or {}

    --- translate to gwindow size
    options.sizeY = math.ceil(3 / options.sizeY)
    ---@diagnostic disable-next-line: redundant-parameter
    GBox.super.new(self, options)

    self.box = pixelbox.new(self.window)
end

---@param pixels GBox.Pixel[]
function GBox:Draw(pixels)
    for _, pixel in ipairs(pixels) do
        self.box.canvas[pixel.y][pixel.x] = pixel.c
    end
    self.box:render()
end

return GBox
