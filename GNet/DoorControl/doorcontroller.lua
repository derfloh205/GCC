local RSController = require("GCC/GNet/redstonecontroller")
local TermUtil = require("GCC/Util/termutil")
local FileDB = require("GCC/Util/filedb")
local f = string.format

---@class DoorControllerDB.Data
---@field doorSides table<number, "left" | "right" | "top" | "bottom" | "front" | "back">
---@field invertSignals boolean
---@field doorCloseDelay number

---@class DoorControllerDB : FileDB
---@field data DoorControllerDB.Data
---@overload fun(options: FileDB.Options) : DoorControllerDB
local DoorControllerDB = FileDB:extend()

---@param options FileDB.Options
function DoorControllerDB:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    DoorControllerDB.super.new(self, options)
end

---@class DoorController.Options : RedstoneController.Options

---@class DoorController : RedstoneController
---@overload fun(options: DoorController.Options) : DoorController
local DoorController = RSController:extend()

DoorController.DEFAULT_CLOSE_DELAY = 2

DoorController.PROTOCOL = {
    DOOR_OPEN = "DOOR_OPEN"
}

---@param options DoorController.Options
function DoorController:new(options)
    options = options or {}
    options.endpointConfigs = {
        {
            protocol = DoorController.PROTOCOL.DOOR_OPEN,
            callback = self.OpenDoors
        }
    }
    ---@diagnostic disable-next-line: redundant-parameter
    DoorController.super.new(self, options)
    self.db = DoorControllerDB {file = "doorcontroller.db"}
    self:Init()
end

function DoorController:Init()
    if not self.db.data.doorSides then
        self.db.data.doorSides = TermUtil:ReadList("Enter door sides (comma-separated):")
    end
    if not self.db.data.doorCloseDelay then
        self.db.data.doorCloseDelay = TermUtil:ReadNumber("Enter door close delay (seconds):")
    end
    if not self.db.data.invertSignals then
        self.db.data.invertSignals = TermUtil:ReadConfirmation("Invert signals?")
    end

    self.db:Persist()

    term.clear()
    term.setCursorPos(1, 1)
    print(f("Door Controller Initiated [%d]", self.id))
    self:CloseDoors()
end

function DoorController:OpenDoors()
    self:FLog("Opening doors")
    local data = self.db.data
    for _, side in ipairs(data.doorSides) do
        redstone.setOutput(side, not data.invertSignals)
    end
    sleep(data.doorCloseDelay)
    self:CloseDoors()
end

function DoorController:CloseDoors()
    self:FLog("Closing doors")
    local data = self.db.data
    for _, side in ipairs(data.doorSides) do
        redstone.setOutput(side, data.invertSignals)
    end
end

return DoorController
