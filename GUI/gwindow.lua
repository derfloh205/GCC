local Object = require("GCC/Util/classics")

---@class GWindow.Options
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
    self.window = window.create(options.parent, options.x, options.y, options.sizeX, options.sizeY, options.visible)
    if options.backgroundColor then
        self.window.setBackgroundColor(options.backgroundColor)
        self:DrawFilledBox(0, 0, options.sizeX, options.sizeY, options.backgroundColor)
    end
    if options.textColor then
        self.window.setTextColor(options.backgroundColor)
    end
end

---@param startX number
---@param startY number
---@param endX number
---@param endY number
---@param color number?
function GWindow:DrawFilledBox(startX, startY, endX, endY, color)
    local t = term.current()
    term.redirect(self.window)
    paintutils.drawFilledBox(startX, startY, endX, endY, color)
    term.redirect(t)
end

---@param txt string
function GWindow:Print(txt)
    local t = term.current()
    term.redirect(self.window)
    print(txt)
    term.redirect(t)
end

function GWindow:Clear()
    local x, y = self.window:GetSize()
    self:DrawFilledBox(0, 0, x, y, colors.black)
end

return GWindow
