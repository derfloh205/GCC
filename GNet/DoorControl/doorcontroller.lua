local RSController = require("GCC/GNet/redstonecontroller")
local TermUtil = require("GCC/Util/termutil")
local FileDB = require("GCC/Util/filedb")

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
        self.doorSides = TermUtil:ReadList("Enter door sides (comma-separated):")
    end
    if not self.db.data.doorCloseDelay then
        self.doorCloseDelay = TermUtil:ReadNumber("Enter door close delay (seconds):")
    end
    if not self.db.data.invertSignals then
        self.invertSignals = TermUtil:ReadConfirmation("Invert signals?")
    end

    term.clear()
    term.setCursorPos(1, 1)
    print("Door Controller Initiated..")
end

function DoorController:OpenDoors()
    for _, side in ipairs(self.doorSides) do
        redstone.setOutput(side, not self.invertSignals)
    end
    sleep(self.doorCloseDelay)
    for _, side in ipairs(self.doorSides) do
        redstone.setOutput(side, self.invertSignals)
    end
end

return DoorController
