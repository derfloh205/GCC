local Object = require("GCC/Util/classics")

---@class GNet
local GNet = {}

---@class GNet.Server.EndpointConfig
---@field protocol? string
---@field callback fun(server: GNet.Server, id: number, msg: string)

---@class GNet.Server.Options
---@field endpointConfigs GNet.Server.EndpointConfig[]

---@class GNet.Server : Object
---@overload fun(options: GNet.Server.Options) : GNet.Server
GNet.Server = Object:extend()

---@param options GNet.Server.Options
function GNet.Server:new(options)
    options = options or {}
    ---@type GNet.Server.EndpointConfig[]
    self.endpoints = options.endpointConfigs or {}
    self.id = os.getComputerID()
    peripheral.find("modem", rednet.open)
end

function GNet.Server:Run()
    local endpointCallbacks = {}

    for _, endpoint in ipairs(self.endpoints) do
        table.insert(
            endpointCallbacks,
            function()
                while true do
                    local id, msg = rednet.receive(endpoint.protocol)
                    endpoint.callback(self, id, msg)
                end
            end
        )
    end

    parallel.waitForAll(table.unpack(endpointCallbacks))
end

return GNet
