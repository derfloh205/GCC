local Object = require("GCC/Util/classics")
local GLogAble = require("GCC/Util/glog")
local GWindow = require("GCC/GUI/gwindow")
local MUtil = require("GCC/Util/mutil")
local GBox = require("GCC/GUI/gbox")

---@class GUI
local GUI = {}

---@class GUI.Icon.Options : GBox.Options
---@field pixels? GBox.Pixel[]

---@class GUI.Icon : GBox
---@overload fun(options: GUI.Icon.Options) : GUI.Icon
GUI.Icon = GBox:extend()

---@param options GUI.Icon.Options
function GUI.Icon:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    GUI.Icon.super.new(self, options)

    if options.pixels then
        self:Draw(options.pixels)
    end
end

---@class GUI.Clickable.Options
---@field frontend GUI.Frontend
---@field parent? table
---@field posX number
---@field posY number
---@field sizeX number
---@field sizeY number
---@field clickCallback fun(self: GUI.Clickable)

---@class GUI.Clickable : Object
---@overload fun(options: GUI.Clickable.Options) : GUI.Clickable
GUI.Clickable = Object:extend()

---@param options GUI.Clickable.Options
function GUI.Clickable:new(options)
    options = options or {}
    self.frontend = options.frontend
    self.gWindow =
        GWindow {
        monitor = self.frontend.monitor,
        parent = options.parent or term.native(),
        sizeX = options.sizeX,
        sizeY = options.sizeY,
        x = options.posX,
        y = options.posY
    }
    self.clickCallback = options.clickCallback
    self.frontend:RegisterClickable(self)
end

---@param x number
---@param y number
---@return boolean clicked
function GUI.Clickable:IsClicked(x, y)
    local posX, posY = self.gWindow:GetPosition()
    local sizeX, sizeY = self.gWindow:GetSize()
    --term.native().write("RangeCheck: " .. posX .. "/" .. sizeX)
    --term.native().write("RangeCheck: " .. posY .. "/" .. sizeY)
    local inX = MUtil:InRange(x, posX, posX + sizeX)
    local inY = MUtil:InRange(y, posY, posY + sizeY)
    return inX and inY
end

---@class GUI.Button.Options : GUI.Clickable.Options
---@field backgroundColor? number
---@field textColor? number
---@field label string

---@class GUI.Button : GUI.Clickable
---@overload fun(options: GUI.Button.Options) : GUI.Button
GUI.Button = GUI.Clickable:extend()

---@param options GUI.Button.Options
function GUI.Button:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    GUI.Button.super.new(self, options)
    if options.backgroundColor then
        self.gWindow:SetBackgroundColor(options.backgroundColor)
    end
    if options.textColor then
        self.gWindow:SetTextColor(options.textColor)
    end
    if options.label then
        self.gWindow:Print(options.label)
    end
end

---@class GUI.Frontend.Options
---@field touchscreen? boolean
---@field monitor table wrapped monitor or terminal

---@class GUI.Frontend : GLogAble
---@overload fun(options: GUI.Frontend.Options) : GUI.Frontend
GUI.Frontend = GLogAble:extend()

---@param options GUI.Frontend.Options
function GUI.Frontend:new(options)
    options = options or {}
    self.touchscreen = options.touchscreen
    self.monitor = options.monitor
    if self.monitor ~= term.current() then
        term.redirect(self.monitor)
    end

    self.monitor.clear()
    self.monitor.setCursorPos(1, 1)

    ---@type GUI.Clickable[]
    self.clickables = {}
end

function GUI.Frontend:RegisterClickable(clickable)
    table.insert(self.clickables, clickable)
end

--- Listens for Click Events for each clickable
function GUI.Frontend:Run()
    local clickHandlers = {}

    for i, clickable in ipairs(self.clickables) do
        table.insert(
            clickHandlers,
            function()
                while true do
                    if self.touchscreen then
                        local _, _, x, y = os.pullEvent("monitor_touch")
                        -- term.native().clear()
                        -- term.native().setCursorPos(1, 1)
                        -- term.native().write("touched: " .. x .. "/" .. y)
                        if clickable:IsClicked(x, y) then
                            clickable.clickCallback(clickable)
                        end
                    else
                        local _, _, x, y = os.pullEvent("mouse_click")
                        -- term.native().clear()
                        -- term.native().setCursorPos(1, 1)
                        -- term.native().write("clicked: " .. x .. "/" .. y)
                        if clickable:IsClicked(x, y) then
                            clickable.clickCallback(clickable)
                        end
                    end
                end
            end
        )
    end

    if #clickHandlers > 0 then
        parallel.waitForAll(table.unpack(clickHandlers))
    end
end

return GUI
