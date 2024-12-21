local GAuth = require("GCC/GAuth/gauth")
local DoorController = require("GCC/GNet/DoorControl/doorcontroller")

---@class DoorAuthHost.Options : GAuth.AuthHost.Options
---@field doorControllerID number

---@class DoorAuthHost : GAuth.AuthHost
---@overload fun(options: DoorAuthHost.Options) : DoorAuthHost
local DoorAuthHost = GAuth.AuthHost:extend()

---@param options DoorAuthHost.Options
function DoorAuthHost:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    self.super.new(self, options)
    self.doorControllerID = options.doorControllerID
end

function DoorAuthHost:OpenDoors()
    rednet.send(self.doorControllerID, DoorController.PROTOCOL.DOOR_OPEN)
end
