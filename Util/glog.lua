local Object = require("GCC/Util/classics")
local p = require("cc.pretty")
local f = string.format

---@class GLogAble.Options
---@field log? boolean
---@field logFile? string
---@field clearLog? boolean
---@field logFeedSize? number default: 0

---@class GLogAble : Object
local GLogAble = Object:extend()

---@param options GLogAble.Options
function GLogAble:new(options)
    options = options or {}
    self.log = false
    self.logFile = ""
    ---@type string[]
    self.logFeed = {}
    self.logFeedSize = options.logFeedSize or 0
    self:SetLogFile(options.logFile)
    self:SetLog(options.log)
    if options.clearLog then
        self:ClearLog()
    end
end

function GLogAble:AddLogFeed(logString)
    if self.logFeedSize == 0 then
        return
    end

    table.insert(self.logFeed, logString)
    if #self.logFeed > self.logFeedSize then
        table.remove(self.logFeed, 1)
    end
end

function GLogAble:ClearLog()
    if self.logFile and self.logFile ~= "" and fs.exists(self.logFile) then
        fs.delete(self.logFile)
    end
end

---@param log boolean
function GLogAble:SetLog(log)
    self.log = log or false
end

function GLogAble:SetLogFile(logFile)
    self.logFile = logFile
end

---@param logString string?
---@param logFeed boolean?
function GLogAble:WriteLogFile(logString, logFeed)
    if logFeed then
        self:AddLogFeed(logString)
    end

    if not self.logFile then
        return
    end

    local logFile = fs.open(self.logFile, "a")
    logFile.write(f("[%s]: %s\n", os.date("%T"), logString or ""))
    logFile.close()
end

---@param logString string | table
---@param addToLogFeed? boolean
function GLogAble:Log(logString, addToLogFeed)
    if not self.log then
        return
    end

    self:WriteLogFile(tostring(logString), addToLogFeed)
end

function GLogAble:LogFeed(logString)
    self:Log(logString, true)
end

function GLogAble:GetFLogString(...)
    local varArgs = {...}
    local fString = varArgs[1]
    local strings = {}
    for i, arg in ipairs(varArgs) do
        if i > 1 then
            table.insert(strings, tostring(arg))
        end
    end

    return f(fString, table.unpack(strings))
end

---@param ... any
function GLogAble:FLog(...)
    local flogString = self:GetFLogString(...)
    self:Log(flogString)
end

function GLogAble:FLogFeed(...)
    local flogString = self:GetFLogString(...)
    self:LogFeed(flogString)
end

function GLogAble:LogTable(t)
    if not self.log then
        return
    end
    local logString = f("\n%s", tostring(textutils.serialise(t)))
    self:WriteLogFile(logString)
end

return GLogAble
