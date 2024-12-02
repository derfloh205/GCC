local Object = require("GCC/Util/classics")

---@class GNet
local GNet = {}

---@class GNet.Server : Object
---@overload fun(options: GNet.Server.Options) : GNet.Server
GNet.Server = Object:extend()

return GNet
