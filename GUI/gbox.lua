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

    if options.sizeY % 3 ~= 0 then
        error("GBox: X and Y needs to be multiples of 2 and 3 respectively")
    end

    --- translate to gwindow size
    options.sizeY = options.sizeY / 3
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
