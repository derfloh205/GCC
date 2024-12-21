local GAuth = require("GCC/GAuth/gauth")
local DoorController = require("GCC/GNet/DoorControl/doorcontroller")
local FileDB = require("GCC/Util/filedb")
local TermUtil = require("GCC/Util/termutil")
local GNav = require("GCC/GNav/gnav")
local GUI = require("GCC/GUI/gui")
local f = string.format

---@class DoorAuthHostDB.Data
---@field permittedUsers string[]
---@field permittedBoundary GNAV.Boundary
---@field doorControllerID number

---@class DoorAuthHostDB : FileDB
---@field data DoorAuthHostDB.Data
---@overload fun(options: FileDB.Options) : DoorAuthHostDB
local DoorAuthHostDB = FileDB:extend()

function DoorAuthHostDB:DeserializeData(data)
    return {
        permittedUsers = data.permittedUsers,
        doorControllerID = data.doorControllerID,
        permittedBoundary = data.permittedBoundary and GNav.Boundary:Deserialize(data.permittedBoundary)
    }
end

function DoorAuthHostDB:SerializeData()
    return {
        permittedUsers = self.data.permittedUsers,
        doorControllerID = self.data.doorControllerID,
        permittedBoundary = self.data.permittedBoundary and self.data.permittedBoundary:Serialize()
    }
end

---@class DoorAuthHost.Options : GAuth.AuthHost.Options

---@class DoorAuthHost : GAuth.AuthHost
---@overload fun(options: DoorAuthHost.Options) : DoorAuthHost
local DoorAuthHost = GAuth.AuthHost:extend()

---@param options DoorAuthHost.Options
function DoorAuthHost:new(options)
    options = options or {}
    options.onUserAuthenticated = function(id, authenticationMsg)
        self:FLog("User Authenticated: %s", authenticationMsg.username)
        self:ShowAuthentication(authenticationMsg.username)
        self:OpenDoors()
        sleep(1)
        self:ShowDefaultText()
    end
    ---@diagnostic disable-next-line: redundant-parameter
    DoorAuthHost.super.new(self, options)
    self.db = DoorAuthHostDB {file = "doorauthhost.db"}
    self:InitFrontend()
    self:Init()
end

function DoorAuthHost:InitFrontend()
    self.ui = {}
    self.ui.frontend =
        GUI.Frontend {
        monitor = term.current(),
        touchscreen = true
    }

    self.ui.authText =
        GUI.Text {
        monitor = self.ui.frontend.monitor,
        parent = self.ui.frontend.monitor,
        x = 12,
        y = 7,
        sizeX = 50,
        sizeY = 2,
        text = "Door Authentication System",
        textColor = colors.yellow
    }
end

function DoorAuthHost:ShowDefaultText()
    self.ui.authText:SetText("Door Authentication System", colors.yellow)
end
function DoorAuthHost:ShowAuthentication(user)
    self.ui.authText:SetText("Welcome, " .. user, colors.green)
end

function DoorAuthHost:Init()
    local prevTerm = term.current()
    term.redirect(term.native())
    if not self.db.data.permittedUsers then
        self.db.data.permittedUsers = TermUtil:ReadList("Enter permitted users (comma-separated):")
    end
    if not self.db.data.permittedBoundary then
        local positions = {}
        for i = 1, 3 do
            local pos = TermUtil:ReadGVector(f("Enter Boundary Corner #%d:", i))
            table.insert(positions, pos)
        end
        self:SetPermittedBoundary(positions)
        self.db.data.permittedBoundary = self.permittedBoundary
    end

    if not self.db.data.doorControllerID then
        self.db.data.doorControllerID = TermUtil:ReadNumber("Enter Door Controller ID:")
    end

    self.permittedUsers = self.db.data.permittedUsers
    self.permittedBoundary = self.db.data.permittedBoundary

    term.clear()
    term.setCursorPos(1, 1)

    self:FLog("Door Auth Host Initiated [%d]", self.id)

    self.db:Persist()

    term.redirect(prevTerm)
end

function DoorAuthHost:OpenDoors()
    rednet.send(self.db.data.doorControllerID, nil, DoorController.PROTOCOL.DOOR_OPEN)
end

return DoorAuthHost
