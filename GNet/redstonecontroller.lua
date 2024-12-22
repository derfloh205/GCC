local GNet = require("GCC/GNet/gnet")

---@class RedstoneController.Options : GNet.Server.Options

---@class RedstoneController : GNet.Server
---@overload fun(options: RedstoneController.Options) : RedstoneController
local RedstoneController = GNet.Server:extend()

---@class RedstoneController.Command
---@field side string | "left" | "right" | "top" | "bottom" | "front" | "back"
---@field value boolean

---@class RedstoneController.NetworkMessage
---@field commands RedstoneController.Command[]
---@field revertDelay number

RedstoneController.PROTOCOL = {
    REDSTONE_COMMAND = "REDSTONE_COMMAND"
}

---@param options RedstoneController.Options
function RedstoneController:new(options)
    options = options or {}
    options.endpointConfigs = {
        {
            protocol = RedstoneController.PROTOCOL.REDSTONE_COMMAND,
            callback = self.OnRedstoneCommand
        }
    }
    ---@diagnostic disable-next-line: redundant-parameter
    RedstoneController.super.new(self, options)
end

---@param id number
---@param commandMsg RedstoneController.NetworkMessage
function RedstoneController:OnRedstoneCommand(id, commandMsg)
    self:FLog("Received redstone command")
    for _, command in ipairs(commandMsg.commands) do
        redstone.setOutput(command.side, command.value)
    end
    if commandMsg.revertDelay then
        sleep(commandMsg.revertDelay)
        for _, command in ipairs(commandMsg.commands) do
            redstone.setOutput(command.side, not command.value)
        end
    end
end

return RedstoneController
