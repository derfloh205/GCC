---@class GNet
local GNet = {}

---@enum GNet.PROTOCOL
GNet.PROTOCOL = {
    TURTLE_HOST_SEARCH = "TURTLE_HOST_SEARCH",
    LOG = "LOG",
    REPLACE = "REPLACE"
}

---@alias TurtleID number

---@class GNet.TurtleHost.Options
---@field term table?

---@class GNet.TurtleHost : Object
---@overload fun(options: GNet.TurtleHost.Options) : GNet.TurtleHost
GNet.TurtleHost = Object:extend()

---@param options GNet.TurtleHost.Options
function GNet.TurtleHost:new(options)
    self.id = os.getComputerID()
    self.name = "TurtleHost_" .. self.id
    self.term = options.term or term

    peripheral.find("modem", rednet.open)

    ---@type TurtleID[]
    self.registeredTurtles = {}
end

function GNet.TurtleHost:StartServer()
    local function OnTurtleHostSearch()
        while true do
            local id, _ = rednet.receive(GNet.PROTOCOL.TURTLE_HOST_SEARCH)
            table.insert(self.registeredTurtles, id)
            rednet.send(id, "Hello There!", GNet.PROTOCOL.TURTLE_HOST_SEARCH)
        end
    end

    local function OnLog()
        while true do
            local id, msg = rednet.receive(GNet.PROTOCOL.LOG)
            local _, y = self.term.getCursorPos()
            self.term.write(string.format("[T%d]: %s", id, msg))
            self.term.setCursorPos(1, y + 1)
        end
    end

    local function OnReplace()
        while true do
            local id, msg = rednet.receive(GNet.PROTOCOL.REPLACE)
            self.term.clear()
            self.term.setCursorPos(1, 1)
            self.term.write(msg)
        end
    end

    parallel.waitForAll(OnTurtleHostSearch, OnLog, OnReplace)
end

---@class GNet.TurtleHostComm.Options
---@field gTurtle GTurtle.Base

---@class GNet.TurtleHostComm : Object
---@overload fun(options: GNet.TurtleHostComm.Options) : GNet.TurtleHostComm
GNet.TurtleHostComm = Object:extend()

---@param options GNet.TurtleHostComm
function GNet.TurtleHostComm:new(options)
    self.gTurtle = options.gTurtle
    -- open all rednet modems attached to turtle
    peripheral.find("modem", rednet.open)
    self.hostID = self:SearchTurtleHost()
end

function GNet.TurtleHostComm:SearchTurtleHost()
    rednet.broadcast("Searching For Turtle Host..", GNet.PROTOCOL.TURTLE_HOST_SEARCH)

    self.hostID = rednet.receive(GNet.PROTOCOL.TURTLE_HOST_SEARCH, 2)

    if self.hostID then
        self.gTurtle:Log(string.format("Found Turtle Host (ID: %d)"))
        self:SendLog("Hello There!")
    else
        self.gTurtle:Log("No Turtle Host Found")
    end
end

function GNet.TurtleHostComm:SendLog(msg)
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, msg, GNet.PROTOCOL.LOG)
end

function GNet.TurtleHostComm:SendReplace(msg)
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, msg, GNet.PROTOCOL.REPLACE)
end

return GNet
