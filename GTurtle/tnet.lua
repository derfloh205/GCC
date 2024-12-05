local GLogAble = require("GCC/Util/glog")
local GNet = require("GCC/GNet/gnet")
local TUtil = require("GCC/Util/tutil")
local TNav = require("GCC/GTurtle/tnav")
local f = string.format

---@class GTurtle.TurtleNet
local TurtleNet = {}

---@class TurtleNet.TurtleHost.TurtleData
---@field id number
---@field pos Vector

---@class TurtleNet.TurtleHost.Options : GNet.Server.Options

---@class TurtleNet.TurtleHost : GNet.Server
---@overload fun(options: TurtleNet.TurtleHost.Options) : TurtleNet.TurtleHost
TurtleNet.TurtleHost = GNet.Server:extend()

---@enum TurtleNet.TurtleHost.PROTOCOL
TurtleNet.TurtleHost.PROTOCOL = {
    TURTLE_HOST_SEARCH = "TURTLE_HOST_SEARCH",
    LOG = "LOG",
    REPLACE = "REPLACE",
    MAP_UPDATE = "MAP_UPDATE",
    TURTLE_POS_UPDATE = "TURTLE_POS_UPDATE"
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
        },
        {
            protocol = self.PROTOCOL.MAP_UPDATE,
            callback = self.OnMapUpdate
        },
        {
            protocol = self.PROTOCOL.TURTLE_POS_UPDATE,
            callback = self.OnTurtlePosUpdate
        }
    }

    options.endpointConfigs = options.endpointConfigs or {}

    options.endpointConfigs = TUtil:Concat(options.endpointConfigs or {}, defaultEndpointConfigs)

    ---@diagnostic disable-next-line: redundant-parameter
    TurtleNet.TurtleHost.super.new(self, options)

    self.name = f("TurtleHost[%d]", self.id)
    os.setComputerLabel(self.name)
    self:SetLogFile(f("%s.log", self.name))
    if options.clearLog then
        self:ClearLog()
    end
    term:clear()
    peripheral.find("modem", rednet.open)

    ---@type table<TurtleID, TurtleNet.TurtleHost.TurtleData>
    self.turtleData = {}
    self.gridMap =
        TNav.GridMap {
        logger = self
    }

    self:Log(f("Initializing %s", self.name))
end

---@param id number
---@param serializedPos Vector
function TurtleNet.TurtleHost:OnTurtleHostSearch(id, serializedPos)
    self:Log(f("Received Host Search Broadcast from [%d]", id))
    self.turtleData[id] = {
        id = id,
        pos = vector.new(serializedPos.x, serializedPos.y, serializedPos.z)
    }

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

function TurtleNet.TurtleHost:OnTurtlePosUpdate(id, serializedPos)
    self:Log(f("Received TURTLE_POS_UPDATE from [%d]", id))
    local turtleData = self.turtleData[id]
    if not turtleData then
        return
    end
    turtleData.pos = vector.new(serializedPos.x, serializedPos.y, serializedPos.z)
end

---@param turtleID number
---@return Vector? pos
function TurtleNet.TurtleHost:GetTurtlePos(turtleID)
    local turtleData = self.turtleData[turtleID]
    if turtleData then
        return turtleData.pos
    end
    self:FLog("Error: Could not get pos for [%d]", turtleID)
end

function TurtleNet.TurtleHost:UpdateGridMapDisplay(turtleID)
    local turtlePos = self:GetTurtlePos(turtleID)
    local gridString = self.gridMap:GetCenteredGridString(turtlePos, 10, 10)
    term.clear()
    term.setCursorPos(1, 1)
    print(gridString)
end

---@param id number
---@param msg string
function TurtleNet.TurtleHost:OnMapUpdate(id, msg)
    self:FLog("Received MAP_UPDATE from [%d]", id)
    local serializedGridMap = msg --[[@as GTurtle.TNAV.GridMap]]
    self:FLog("Boundary Test: X %d / %d", serializedGridMap.boundaries.x.min, serializedGridMap.boundaries.x.max)

    for x, xData in pairs(serializedGridMap.grid) do
        for y, yData in pairs(xData) do
            for z, serializedGridNode in pairs(yData) do
                local gridNode = self.gridMap:GetGridNode(vector.new(x, y, z))
                gridNode.unknown = serializedGridNode.unknown
                gridNode.blockData = serializedGridNode.blockData
            end
        end
    end

    self:UpdateGridMapDisplay(id)
end

---@class TurtleNet.TurtleHostClient.Options : GLogAble.Options
---@field gTurtle GTurtle.Base

---@class TurtleNet.TurtleHostClient : GLogAble
---@overload fun(options: TurtleNet.TurtleHostClient.Options) : TurtleNet.TurtleHostClient
TurtleNet.TurtleHostClient = GLogAble:extend()

---@param options TurtleNet.TurtleHostClient.Options
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
    rednet.broadcast(self.gTurtle.tnav.currentGN.pos, TurtleNet.TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH)

    self.hostID = rednet.receive(TurtleNet.TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH, 2)

    if self.hostID then
        self.gTurtle:Log(string.format("Found Turtle Host [%d]", self.hostID))
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

function TurtleNet.TurtleHostClient:SendPosUpdate()
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, self.gTurtle.tnav.currentGN.pos, TurtleNet.TurtleHost.PROTOCOL.TURTLE_POS_UPDATE)
end

function TurtleNet.TurtleHostClient:SendGridMap()
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, self.gTurtle.tnav.gridMap, TurtleNet.TurtleHost.PROTOCOL.MAP_UPDATE)
end

return TurtleNet
