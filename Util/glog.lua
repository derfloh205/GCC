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

---@param logString string?
function GLogAble:WriteLogFile(logString)
    local logFile = fs.open(self.logFile, "a")
    logFile.write(f("[%s]: %s\n", os.date("%T"), logString or ""))
    logFile.close()
end

---@param logString string | table
function GLogAble:Log(logString)
    if not self.log then
        return
    end

    self:WriteLogFile(tostring(logString))
end

---@param fString string
---@param ... any
---@return string
function GLogAble:FLog(fString, ...)
    local fArgs = ...
    local strings = {}
    for _, arg in fArgs do
        table.insert(strings, tostring(arg))
    end

    return f(fString, table.unpack(strings))
end

function GLogAble:LogTable(t)
    if not self.log then
        return
    end
    local logString = f("\n%s", tostring(textutils.serialise(t)))

    local logFile = fs.open(self.logFile, "a")
    logFile.write(f("[%s]: %s\n", os.date("%T"), logString))
    logFile.close()
end

return GLogAble
