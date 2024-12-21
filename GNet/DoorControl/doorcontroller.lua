local RSController = require("GCC/GNet/redstonecontroller")

---@class DoorController.Options : RedstoneController.Options
---@field doorSides table<number, "left" | "right" | "top" | "bottom" | "front" | "back">
---@field invertSignals boolean
---@field doorCloseDelay number

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
    self.super.new(self, options)
    self.doorSides = options.doorSides or {}
    self.doorCloseDelay = options.doorCloseDelay or self.DEFAULT_CLOSE_DELAY
    self.invertSignals = options.invertSignals or false
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
