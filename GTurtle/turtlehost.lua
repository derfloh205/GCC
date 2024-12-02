local Object = require("GCC/Util/classics")
local GNet = require("GCC/GNet/gnet")

---@class TurtleHost.Options
---@field term table?

---@class TurtleHost : GNet.Server
---@overload fun(options: TurtleHost.Options) : TurtleHost
local TurtleHost = GNet.Server:extend()

---@enum TurtleHost.PROTOCOL
TurtleHost.PROTOCOL = {
    TURTLE_HOST_SEARCH = "TURTLE_HOST_SEARCH",
    LOG = "LOG",
    REPLACE = "REPLACE"
}

---@alias TurtleID number

---@param options TurtleHost.Options
function TurtleHost:new(options)
    options = options or {}
    ---@type GNet.Server.Options
    local serverOptions = {
        endpointConfigs = {
            [self.PROTOCOL.TURTLE_HOST_SEARCH] = self.OnTurtleHostSearch,
            [self.PROTOCOL.LOG] = self.OnLog,
            [self.PROTOCOL.REPLACE] = self.OnReplace
        }
    }
    ---@diagnostic disable-next-line: redundant-parameter
    TurtleHost.super.new(self, serverOptions)

    self.name = "TurtleHost_" .. self.id

    os.setComputerLabel(self.name)
    term:clear()
    peripheral.find("modem", rednet.open)

    ---@type TurtleID[]
    self.registeredTurtles = {}
end

---@param id number
---@param msg string
function TurtleHost:OnTurtleHostSearch(id, msg)
    term.native().write("Waiting for HostSearch...")
    table.insert(self.registeredTurtles, id)
    rednet.send(id, "Hello There!", TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH)
end
---@param id number
---@param msg string
function TurtleHost:OnLog(id, msg)
    print(string.format("[T%d]: %s", id, msg))
end
---@param id number
---@param msg string
function TurtleHost:OnReplace(id, msg)
    term.clear()
    term.setCursorPos(1, 1)
    print(msg)
end

---@class TurtleHostClient.Options
---@field gTurtle GTurtle.Base

---@class TurtleHostClient : Object
---@overload fun(options: TurtleHostClient.Options) : TurtleHostClient
TurtleHostClient = Object:extend()

---@param options TurtleHostClient
function TurtleHostClient:new(options)
    self.gTurtle = options.gTurtle
    -- open all rednet modems attached to turtle
    peripheral.find("modem", rednet.open)
    self:SearchTurtleHost()
end

function TurtleHostClient:SearchTurtleHost()
    rednet.broadcast("Searching For Turtle Host..", TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH)

    self.hostID = rednet.receive(TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH, 2)

    if self.hostID then
        self.gTurtle:Log(string.format("Found Turtle Host (ID: %d)", self.hostID))
        self:SendLog("Hello There!")
    else
        self.gTurtle:Log("No Turtle Host Found")
    end
end

function TurtleHostClient:SendLog(msg)
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, msg, TurtleHost.PROTOCOL.LOG)
end

function TurtleHostClient:SendReplace(msg)
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, msg, TurtleHost.PROTOCOL.REPLACE)
end

return TurtleHost
