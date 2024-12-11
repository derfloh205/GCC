local Object = require("GCC/Util/classics")
local GLogAble = require("GCC/Util/glog")
local GNet = require("GCC/GNet/gnet")
local TUtil = require("GCC/Util/tutil")
local GVector = require("GCC/GNav/gvector")
local GNAV = require("GCC/GNav/gnav")
local GUI = require("GCC/GUI/gui")
local GGrid = require("GCC/GUI/ggrid")
local f = string.format

---@class TNet
local TNet = {}

---@class TNet.TurtleData.Options
---@field id number
---@field pos GVector
---@field state GState.STATE
---@field type GTurtle.TYPES
---@field fuel number

---@class TNet.TurtleData.Serialized
---@field id number
---@field pos GVector.Serialized
---@field state GState.STATE
---@field type GTurtle.TYPES
---@field fuel number

---@class TNet.TurtleData
---@overload fun(options: TNet.TurtleData.Options) : TNet.TurtleData
TNet.TurtleData = Object:extend()

---@param options TNet.TurtleData.Options
function TNet.TurtleData:new(options)
    options = options or {}
    self.id = options.id
    self.pos = options.pos
    self.state = options.state
    self.type = options.type
    self.fuel = options.fuel
end

---@return TNet.TurtleData.Serialized
function TNet.TurtleData:Serialize()
    return {
        id = self.id,
        pos = self.pos:Serialize(),
        state = self.state,
        type = self.type,
        fuel = self.fuel
    }
end

---@return TNet.TurtleData
function TNet.TurtleData:Deserialize(serialized)
    return TNet.TurtleData {
        id = serialized.id,
        pos = GVector:Deserialize(serialized.pos),
        state = serialized.state,
        type = serialized.type,
        fuel = serialized.fuel
    }
end

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
    TURTLE_DATA_UPDATE = "TURTLE_DATA_UPDATE"
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
            protocol = self.PROTOCOL.TURTLE_DATA_UPDATE,
            callback = self.OnTurtleDataUpdate
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

    ---@type table<TurtleID, TNet.TurtleData>
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

    self.ui = {
        frontend = GUI.Frontend {
            touchscreen = true,
            monitor = term.current()
        },
        ---@type GGrid
        ggrid = nil,
        ---@type GUI.Text
        turtleStatusSummary = nil
    }

    self:InitFrontend()

    self:FLog("Initializing %s", self.name)
end

function TNet.TurtleHost:InitFrontend()
    local monitor = self.ui.frontend.monitor
    local mX, mY = monitor.getSize()
    local monitorMidX = math.floor(mX / 2)
    local monitorMidY = math.floor(mY / 2)
    self.ui.ggrid =
        GGrid {
        gridMap = self.gridMap,
        monitor = monitor,
        parent = monitor,
        sizeX = math.floor(mX / 4) * 2,
        sizeY = math.floor(mY / 4) * 3,
        x = monitorMidX,
        y = monitorMidY / 2,
        colorMapFunc = function(gridNode)
            local isTurtlePos =
                TUtil:Some(
                self.turtleData,
                function(turtleData)
                    return gridNode.pos:Equal(turtleData.pos)
                end
            )
            if isTurtlePos then
                return colors.green
            end

            if gridNode:IsUnknown() then
                return colors.gray
            end

            if gridNode:IsEmpty() then
                return colors.black
            end

            return colors.lightGray
        end
    }

    self.ui.title =
        GUI.Text {
        monitor = monitor,
        parent = monitor,
        sizeX = 15,
        sizeY = 2,
        x = monitorMidX - 7,
        y = 2,
        text = "Turtle Host UI"
    }

    self.ui.turtleStatusSummary =
        GUI.Text {
        monitor = monitor,
        parent = monitor,
        sizeX = mX / 2,
        sizeY = mY / 2,
        x = 2,
        y = monitorMidY / 2,
        text = " - Turtle Status -"
    }
end

function TNet.TurtleHost:UpdateTurtleStatusDisplay(turtleID)
    local turtleData = self.turtleData[turtleID]
    if not turtleData then
        return
    end
    local statusText =
        f(
        [[  - Turtle [%d] -
Type:  %s
State: %s
Fuel:  %d
Pos:   %s
]],
        turtleData.id,
        turtleData.type,
        turtleData.state,
        turtleData.fuel,
        tostring(turtleData.pos)
    )

    self.ui.turtleStatusSummary:SetText(statusText)
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
---@param serializedTurtleData TNet.TurtleData.Serialized
function TNet.TurtleHost:OnTurtleDataUpdate(id, serializedTurtleData)
    self:FLog("Received TURTLE_POS_UPDATE from [%d]", id)
    self.turtleData[id] = TNet.TurtleData:Deserialize(serializedTurtleData)
    self:UpdateTurtleStatusDisplay(id)
end

function TNet.TurtleHost:UpdateGridMapDisplay(turtleID)
    local turtleData = self.turtleData[turtleID]
    if turtleData then
        self.ui.ggrid:Update(turtleData.pos)
    end
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
        self:SendTurtleDataUpdate()
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

function TNet.TurtleHostClient:SendTurtleDataUpdate()
    if not self.hostID then
        return
    end
    local turtleData =
        TNet.TurtleData {
        id = self.gTurtle.id,
        type = self.gTurtle.type,
        pos = self.gTurtle.tnav.currentGN.pos,
        fuel = turtle.getFuelLevel(),
        state = self.gTurtle.state
    }
    rednet.send(self.hostID, turtleData:Serialize(), TNet.TurtleHost.PROTOCOL.TURTLE_DATA_UPDATE)
end

function TNet.TurtleHostClient:SendGridMap()
    if not self.hostID then
        return
    end
    rednet.send(self.hostID, self.gTurtle.tnav.gridMap, TNet.TurtleHost.PROTOCOL.MAP_UPDATE)
end

return TNet
