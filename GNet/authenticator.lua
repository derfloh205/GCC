local GNet = require("GCC/GNet/gnet")

---@class Authenticator.AuthenticationMessage
---@field username string

---@class Authenticator.AuthenticationResponse
---@field success boolean
---@field message string

---@class Authenticator.Options : GNet.Server.Options
---@field permittedUsers string[]
---@field scanArea GVector[]

---@class Authenticator : GNet.Server
---@overload fun(options: Authenticator.Options) : Authenticator
local Authenticator = GNet.Server:extend()

Authenticator.PROTOCOL = {
    AUTHENTICATION_REQUEST = "AUTHENTICATION_REQUEST",
    AUTHENTICATION_RESPONSE = "AUTHENTICATION_RESPONSE"
}

---@param options Authenticator.Options
function Authenticator:new(options)
    options = options or {}
    options.endpointConfigs = {
        {
            protocol = Authenticator.PROTOCOL.AUTHENTICATION_REQUEST,
            callback = self.OnAuthenticationRequest
        }
    }
    ---@diagnostic disable-next-line: redundant-parameter
    self.super.new(self, options)

    self.scanArea = options.scanArea or {}
    self.permittedUsers = options.permittedUsers or {}
end

function Authenticator:OnAuthenticationRequest(id, authenticationMsg)
    local response = {
        success = false,
        message = "Invalid authentication message"
    }
    if authenticationMsg.username == "admin" then
        response.success = true
        response.message = "Authentication successful"
    else
        response.success = false
        response.message = "Not authorized"
    end
    self:SendAuthenticationResponse(id, response.success, response.message)
end

function Authenticator:SendAuthenticationResponse(id, success, message)
    local response = {
        success = success,
        message = message
    }
    rednet.send(id, response, Authenticator.PROTOCOL.AUTHENTICATION_RESPONSE)
end
