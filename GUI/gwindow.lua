local Object = require("GCC/Util/classics")

---@class GWindow.Options
---@field monitor table
---@field parent table Window or terminal
---@field backgroundColor number?
---@field textColor number?
---@field x number
---@field y number
---@field sizeX number
---@field sizeY number
---@field visible? boolean

--- wrapper to make paintutils work for terminal windows
---@class GWindow : Object
---@overload fun(options: GWindow.Options) : GWindow
local GWindow = Object:extend()

---@param options GWindow.Options
function GWindow:new(options)
    options = options or {}
    self.monitor = options.monitor
    self.window = window.create(options.parent, options.x, options.y, options.sizeX, options.sizeY, options.visible)
    if options.backgroundColor then
        self:SetBackgroundColor(options.backgroundColor)
    end
    if options.textColor then
        self.window.setTextColor(options.textColor)
    end
end

---@param color number
function GWindow:SetBackgroundColor(color)
    self.window.setBackgroundColor(color)
    local x, y = self.window:getSize()
    self:DrawFilledBox(0, 0, x, y, color)
end

---@param color number
function GWindow:SetTextColor(color)
    self.window.setTextColor(color)
end

---@param startX number
---@param startY number
---@param endX number
---@param endY number
---@param color number?
function GWindow:DrawFilledBox(startX, startY, endX, endY, color)
    self:LockRedirect()
    paintutils.drawFilledBox(startX, startY, endX, endY, color)
    self:FreeRedirect()
end

---@param txt string
function GWindow:Print(txt)
    self:LockRedirect()
    print(txt)
    self:FreeRedirect()
end

function GWindow:Clear()
    local x, y = self.window:getSize()
    self:DrawFilledBox(0, 0, x, y, colors.black)
end

function GWindow:LockRedirect()
    if self.window ~= term.current() then
        term.redirect(self.window)
    end
end

function GWindow:FreeRedirect()
    if term.current() ~= self.monitor then
        term.redirect(self.monitor)
    end
end

---@return number posX
---@return number posY
function GWindow:GetPosition()
    return self.window.getPosition()
end

---@return number sizeX
---@return number sizeY
function GWindow:GetSize()
    return self.window.getSize()
end

return GWindow
