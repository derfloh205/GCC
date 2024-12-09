local GLogAble = require("GCC/Util/glog")
local GNet = require("GCC/GNet/gnet")
local TUtil = require("GCC/Util/tutil")
local GVector = require("GCC/GNav/gvector")
local GNAV = require("GCC/GNav/gnav")
local f = string.format

---@class TNet
local TNet = {}

---@class TNet.TurtleHost.TurtleData
---@field id number
---@field pos GVector

---@class TNet.TurtleHost.Options : GNet.Server.Options

---@class TNet.TurtleHost : GNet.Server
---@overload fun(options: TNet.TurtleHost.Options) : TNet.TurtleHost
TNet.TurtleHost = GNet.Server:extend()

---@enum TNet.TurtleHost.PROTOCOL
TNet.TurtleHost.PROTOCOL = {
    TURTLE_HOST_SEARCH = "TURTLE_HOST_SEARCH",
    LOG = "LOG",
    REPLACE = "REPLACE",
    MAP_UPDATE = "MAP_UPDATE",
    TURTLE_POS_UPDATE = "TURTLE_POS_UPDATE"
}

---@alias TurtleID number

---@param options TNet.TurtleHost.Options
function TNet.TurtleHost:new(options)
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
    TNet.TurtleHost.super.new(self, options)

    self.name = f("TurtleHost[%d]", self.id)
    os.setComputerLabel(self.name)
    self:SetLogFile(f("%s.log", self.name))
    if options.clearLog then
        self:ClearLog()
    end
    term:clear()
    peripheral.find("modem", rednet.open)

    ---@type table<TurtleID, TNet.TurtleHost.TurtleData>
    self.turtleData = {}
    self.gridMap =
        GNAV.GridMap {
        logger = self,
        gridNodeMapFunc = function(gridNode)
            for id, turtleData in pairs(self.turtleData) do
                if turtleData.pos:Equal(gridNode.pos) then
                    return f("[%d]", id)
                end
            end
        end
    }

    self:FLog("Initializing %s", self.name)
end

---@param id number
---@param serializedGV GVector.Serialized
function TNet.TurtleHost:OnTurtleHostSearch(id, serializedGV)
    self:Log(f("Received Host Search Broadcast from [%d]", id))
    self.turtleData[id] = {
        id = id,
        pos = GVector:Deserialize(serializedGV)
    }

    rednet.send(id, "Host Search Response", TNet.TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH)
end
---@param id number
---@param msg string
function TNet.TurtleHost:OnLog(id, msg)
    self:FLog("Received LOG from [%d]", id)
    print(string.format("[T%d]: %s", id, msg))
end
---@param id number
---@param msg string
function TNet.TurtleHost:OnReplace(id, msg)
    self:FLog("Received REPLACE from [%d]", id)
    term.clear()
    term.setCursorPos(1, 1)
    print(msg)
end

---@param id number
---@param serializedGV GVector.Serialized
function TNet.TurtleHost:OnTurtlePosUpdate(id, serializedGV)
    self:FLog("Received TURTLE_POS_UPDATE from [%d]", id)
    local turtleData = self.turtleData[id]
    if not turtleData then
        return
    end
    turtleData.pos = GVector:Deserialize(serializedGV)
end

---@param turtleID number
---@return GVector? pos
function TNet.TurtleHost:GetTurtlePos(turtleID)
    local turtleData = self.turtleData[turtleID]
    if turtleData then
        return turtleData.pos
    end
    self:FLog("Error: Could not get pos for [%d]", turtleID)
end

function TNet.TurtleHost:UpdateGridMapDisplay(turtleID)
    local turtlePos = self:GetTurtlePos(turtleID)
    local gridString = self.gridMap:GetCenteredGridString(turtlePos, 10, 10)
    term.clear()
    term.setCursorPos(1, 1)
    print(gridString)
end

---@param id number
---@param msg string
function TNet.TurtleHost:OnMapUpdate(id, msg)
    self:FLog("Received MAP_UPDATE from [%d]", id)
    local serializedGridMap = msg --[[@as GNAV.GridMap]]

    self.gridMap:DeserializeGrid(serializedGridMap)

    self:UpdateGridMapDisplay(id)
end

---@class TNet.TurtleHostClient.Options : GLogAble.Options
---@field gTurtle GTurtle.Base

---@class TNet.TurtleHostClient : GLogAble
---@overload fun(options: TNet.TurtleHostClient.Options) : TNet.TurtleHostClient
TNet.TurtleHostClient = GLogAble:extend()

---@param options TNet.TurtleHostClient.Options
function TNet.TurtleHostClient:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    TNet.TurtleHostClient.super.new(self, options)
    self.gTurtle = options.gTurtle
    -- open all rednet modems attached to turtle
    peripheral.find("modem", rednet.open)
    self:SearchTurtleHost()
end

function TNet.TurtleHostClient:SearchTurtleHost()
    rednet.broadcast(self.gTurtle.tnav.currentGN.pos, TNet.TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH)

    self.hostID = rednet.receive(TNet.TurtleHost.PROTOCOL.TURTLE_HOST_SEARCH, 2)

    if self.hostID then
        self.gTurtle:Log(string.format("Found Turtle Host [%d]", self.hostID))
    else
        self.gTurtle:Log("No Turtle Host Found")
    end
end

function TNet.TurtleHostClient:SendLog(msg)
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, msg, TNet.TurtleHost.PROTOCOL.LOG)
end

function TNet.TurtleHostClient:SendReplace(msg)
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, msg, TNet.TurtleHost.PROTOCOL.REPLACE)
end

function TNet.TurtleHostClient:SendPosUpdate()
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, self.gTurtle.tnav.currentGN.pos, TNet.TurtleHost.PROTOCOL.TURTLE_POS_UPDATE)
end

function TNet.TurtleHostClient:SendGridMap()
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, self.gTurtle.tnav.gridMap, TNet.TurtleHost.PROTOCOL.MAP_UPDATE)
end

return TNet
