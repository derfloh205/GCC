local Object = require("GCC/Util/classics")
local GNet = require("GCC/GNet/gnet")

---@class TurtleHost.Options
---@field term table?

---@class TurtleHost : GNet.Server
---@overload fun(options: TurtleHost.Options) : TurtleHost
local TurtleHost = GNet.Server:extend()

---@alias TurtleID number

---@param options TurtleHost.Options
function TurtleHost:new(options)
    TurtleHost.super.new(self, options)

    self.id = os.getComputerID()
    self.name = "TurtleHost_" .. self.id
    ---@enum TurtleHost.PROTOCOL
    self.PROTOCOL = {
        TURTLE_HOST_SEARCH = "TURTLE_HOST_SEARCH",
        LOG = "LOG",
        REPLACE = "REPLACE"
    }
    term:clear()
    peripheral.find("modem", rednet.open)

    ---@type TurtleID[]
    self.registeredTurtles = {}
end

function TurtleHost:StartServer()
    local function OnTurtleHostSearch()
        while true do
            term.native().write("Waiting for HostSearch...")
            local id, _ = rednet.receive(TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH)
            table.insert(self.registeredTurtles, id)
            rednet.send(id, "Hello There!", TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH)
        end
    end

    local function OnLog()
        while true do
            term.native().write("Waiting for Log...")
            local id, msg = rednet.receive(TurtleHost.PROTOCOL.LOG)
            print(string.format("[T%d]: %s", id, msg))
        end
    end

    local function OnReplace()
        while true do
            term.native().write("Waiting for Replace...")
            local id, msg = rednet.receive(TurtleHost.PROTOCOL.REPLACE)
            term.clear()
            term.setCursorPos(1, 1)
            print(msg)
        end
    end

    parallel.waitForAll(OnTurtleHostSearch, OnLog, OnReplace)
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
