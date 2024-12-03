local GLogAble = require("GCC/Util/glog")
local GNet = require("GCC/GNet/gnet")
local TUtil = require("GCC/Util/tutil")
local f = string.format

---@class GTurtle.TurtleNet
local TurtleNet = {}

---@class TurtleNet.TurtleHost.Options : GNet.Server.Options

---@class TurtleNet.TurtleHost : GNet.Server
---@overload fun(options: TurtleNet.TurtleHost.Options) : TurtleNet.TurtleHost
TurtleNet.TurtleHost = GNet.Server:extend()

---@enum TurtleNet.TurtleHost.PROTOCOL
TurtleNet.TurtleHost.PROTOCOL = {
    TURTLE_HOST_SEARCH = "TURTLE_HOST_SEARCH",
    LOG = "LOG",
    REPLACE = "REPLACE"
}

---@alias TurtleID number

---@param options TurtleNet.TurtleHost.Options
function TurtleNet.TurtleHost:new(options)
    options = options or {}
    ---@type GNet.Server.EndpointConfig[]
    local defaultEndpointConfigs = {
        {
            protocol = self.PROTOCOL.TURTLE_HOST_SEARCH,
            callback = self.OnTurtleHostSearch
        },
        {
            protocol = self.PROTOCOL.LOG,
            callback = self.OnLog
        },
        {
            protocol = self.PROTOCOL.REPLACE,
            callback = self.OnReplace
        }
    }

    options.endpointConfigs = options.endpointConfigs or {}

    options.endpointConfigs = TUtil:Concat(options.endpointConfigs or {}, defaultEndpointConfigs)

    ---@diagnostic disable-next-line: redundant-parameter
    TurtleNet.TurtleHost.super.new(self, options)

    self.name = f("TurtleHost[%d]", self.id)
    os.setComputerLabel(self.name)
    self:SetLogFile(f("%s.log", self.name))
    term:clear()
    peripheral.find("modem", rednet.open)

    ---@type TurtleID[]
    self.registeredTurtles = {}

    self:Log(f("Initializing %s", self.name))
end

---@param id number
---@param msg string
function TurtleNet.TurtleHost:OnTurtleHostSearch(id, msg)
    self:Log(f("Received Host Search Broadcast from [%d]", id))
    table.insert(self.registeredTurtles, id)
    rednet.send(id, "Host Search Response", TurtleNet.TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH)
end
---@param id number
---@param msg string
function TurtleNet.TurtleHost:OnLog(id, msg)
    self:Log(f("Received LOG from [%d]", id))
    print(string.format("[T%d]: %s", id, msg))
end
---@param id number
---@param msg string
function TurtleNet.TurtleHost:OnReplace(id, msg)
    self:Log(f("Received REPLACE from [%d]", id))
    term.clear()
    term.setCursorPos(1, 1)
    print(msg)
end

---@class TurtleNet.TurtleHostClient.Options : GLogAble.Options
---@field gTurtle GTurtle.Base

---@class TurtleNet.TurtleHostClient : GLogAble
---@overload fun(options: TurtleNet.TurtleHostClient.Options) : TurtleNet.TurtleHostClient
TurtleNet.TurtleHostClient = GLogAble:extend()

---@param options TurtleNet.TurtleHostClient
function TurtleNet.TurtleHostClient:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    TurtleNet.TurtleHostClient.super.new(self, options)
    self.gTurtle = options.gTurtle
    -- open all rednet modems attached to turtle
    peripheral.find("modem", rednet.open)
    self:SearchTurtleHost()
end

function TurtleNet.TurtleHostClient:SearchTurtleHost()
    rednet.broadcast("Searching For Turtle Host..", TurtleNet.TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH)

    self.hostID = rednet.receive(TurtleNet.TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH, 2)

    if self.hostID then
        self.gTurtle:Log(string.format("Found Turtle Host (ID: %d)", self.hostID))
    else
        self.gTurtle:Log("No Turtle Host Found")
    end
end

function TurtleNet.TurtleHostClient:SendLog(msg)
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, msg, TurtleNet.TurtleHost.PROTOCOL.LOG)
end

function TurtleNet.TurtleHostClient:SendReplace(msg)
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, msg, TurtleNet.TurtleHost.PROTOCOL.REPLACE)
end

return TurtleNet
