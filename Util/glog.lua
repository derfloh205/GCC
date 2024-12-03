local Object = require("GCC/Util/classics")
local p = require("cc.pretty")
local f = string.format

---@class GLogAble.Options
---@field log boolean
---@field logFile? string
---@field clearLog? boolean

---@class GLogAble : Object
local GLogAble = Object:extend()

---@param options GLogAble.Options
function GLogAble:new(options)
    options = options or {}
    self.log = false
    self.logFile = ""
    self:SetLogFile(options.logFile)
    self:SetLog(options.log)
    if options.clearLog then
        self:ClearLog()
    end
end

function GLogAble:ClearLog()
    if self.logFile ~= "" and fs.exists(self.logFile) then
        fs.delete(self.logFile)
    end
end

---@param log boolean
function GLogAble:SetLog(log)
    self.log = log or false
end

function GLogAble:SetLogFile(logFile)
    self.logFile = logFile or f("PC_%d.log", os.getComputerID())
end

---@param logValue string | table
function GLogAble:Log(logValue)
    if not self.log then
        return
    end
    local logString = logValue
    if type(logValue) == "table" then
        logString = f("\n%s", tostring(textutils.serialise(logValue)))
    end

    local logFile = fs.open(self.logFile, "a")
    logFile.write(f("[%s]: %s\n", os.date("%T"), logString))
    logFile.close()
end

return GLogAble
