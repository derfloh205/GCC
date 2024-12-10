local Object = require("GCC/Util/classics")
local GLogAble = require("GCC/Util/glog")
---@class GUI
local GUI = {}

---@class GUI.Clickable.Options
---@field frontend GUI.Frontend
---@field clickCallback fun(self: GUI.Clickable)

---@class GUI.Clickable : Object
---@overload fun(options: GUI.Clickable.Options) : GUI.Clickable
GUI.Clickable = Object:extend()

---@param options GUI.Clickable.Options
function GUI.Clickable:new(options)
    options = options or {}
    self.frontend = options.frontend
    self.frontend:RegisterClickable(self)
end

---@class GUI.Button.Options : GUI.Clickable.Options
---@field backgroundColor? number
---@field textColor? number
---@field label string
---@field sizeX number
---@field sizeY number

---@class GUI.Button : GUI.Clickable
---@overload fun(options: GUI.Button.Options) : GUI.Button
GUI.Button = GUI.Clickable:extend()

---@param options GUI.Button.Options
function GUI.Button:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    GUI.Button.super.new(self, options)
end

---@class GUI.Frontend.Options

---@class GUI.Frontend : GLogAble
---@overload fun(options: GUI.Frontend.Options) : GUI.Frontend
GUI.Frontend = GLogAble:extend()

---@param options GUI.Frontend.Options
function GUI.Frontend:new(options)
    options = options or {}
    ---@type GUI.Clickable[]
    self.clickables = {}
end

function GUI.Frontend:RegisterClickable(clickable)
    table.insert(self.clickables, clickable)
end

return GUI
