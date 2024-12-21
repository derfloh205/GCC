local GNet = require("GCC/GNet/gnet")
local GLogAble = require("GCC/Util/glog")
local TUtil = require("GCC/Util/tutil")
local TermUtil = require("GCC/Util/termutil")

---@class GAuth
local GAuth = {}

---@class GAuth.AuthHost.AuthenticationMessage
---@field username string
---@field position GVector

---@class GAuth.AuthHost.AuthenticationResponse
---@field success boolean
---@field message string

---@class GAuth.AuthHost.Options : GNet.Server.Options
---@field permittedUsers string[]
---@field permittedPositions GVector[]
---@field onUserAuthenticated fun(id: number, authenticationMsg: GAuth.AuthHost.AuthenticationMessage)

---@class GAuth.AuthHost : GNet.Server
---@overload fun(options: GAuth.AuthHost.Options) : GAuth.AuthHost
GAuth.AuthHost = GNet.Server:extend()

GAuth.AuthHost.PROTOCOL = {
    AUTHENTICATION_REQUEST = "AUTHENTICATION_REQUEST",
    AUTHENTICATION_RESPONSE = "AUTHENTICATION_RESPONSE"
}

---@param options GAuth.AuthHost.Options
function GAuth.AuthHost:new(options)
    options = options or {}
    options.endpointConfigs = {
        {
            protocol = GAuth.AuthHost.PROTOCOL.AUTHENTICATION_REQUEST,
            callback = self.OnAuthenticationRequest
        }
    }
    ---@diagnostic disable-next-line: redundant-parameter
    GAuth.AuthHost.super.new(self, options)

    self.permittedPositions = options.permittedPositions or {}
    self.permittedUsers = options.permittedUsers or {}
    self.onUserAuthenticated = options.onUserAuthenticated
end

---@param userPosition GVector
function GAuth.AuthHost:InScanArea(userPosition)
    for _, position in ipairs(self.permittedPositions) do
        if userPosition:Equal(position) then
            return true
        end
    end
    return false
end

---@param id number
---@param authenticationMsg GAuth.AuthHost.AuthenticationMessage
function GAuth.AuthHost:OnAuthenticationRequest(id, authenticationMsg)
    local response = {
        success = false,
        message = "Invalid authentication message"
    }
    local userPermitted = TUtil:tContains(self.permittedUsers, authenticationMsg.username)
    local positionPermitted = self:InScanArea(authenticationMsg.position)
    if userPermitted and positionPermitted then
        response.success = true
        response.message = "Authentication successful"
        if self.onUserAuthenticated then
            self.onUserAuthenticated(id, authenticationMsg)
        end
    elseif userPermitted then
        response.success = false
        response.message = "Position not within scan area"
    else
        response.success = false
        response.message = "Not authorized"
    end
    self:SendAuthenticationResponse(id, response.success, response.message)
end

function GAuth.AuthHost:SendAuthenticationResponse(id, success, message)
    local response = {
        success = success,
        message = message
    }
    rednet.send(id, response, GAuth.AuthHost.PROTOCOL.AUTHENTICATION_RESPONSE)
end

---@class GAuth.AuthClient.Options : GLogAble.Options

---@class GAuth.AuthClient : GLogAble
---@overload fun(options: GAuth.AuthClient.Options) : GAuth.AuthClient
GAuth.AuthClient = GLogAble:extend()

---@param options GAuth.AuthClient.Options
function GAuth.AuthClient:new(options)
    options = options or {}
    self.id = os.getComputerID()
    ---@diagnostic disable-next-line: redundant-parameter
    GAuth.AuthClient.super.new(self, options)
    self:Login()
    self:Run()
end

function GAuth.AuthClient:Run()
end

function GAuth.AuthClient:Login()
    self.username = TermUtil:ReadString("Enter username: ")
end

---@param username string
---@param position GVector
---@param timeout number
---@return GAuth.AuthHost.AuthenticationResponse?
function GAuth.AuthClient:BroadcastAuthenticationRequest(username, position, timeout)
    ---@type GAuth.AuthHost.AuthenticationMessage
    local request = {
        username = username,
        position = position
    }
    rednet.broadcast(request, GAuth.AuthHost.PROTOCOL.AUTHENTICATION_REQUEST)
    local response = rednet.receive(GAuth.AuthHost.PROTOCOL.AUTHENTICATION_RESPONSE, timeout)
    return response
end

return GAuth
