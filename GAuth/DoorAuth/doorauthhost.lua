local GAuth = require("GCC/GAuth/gauth")
local DoorController = require("GCC/GNet/DoorControl/doorcontroller")
local FileDB = require("GCC/Util/filedb")
local TermUtil = require("GCC/Util/termutil")
local GVector = require("GCC/GNav/gvector")
local f = string.format

---@class DoorAuthHostDB.Data
---@field permittedUsers string[]
---@field permittedPositions GVector[]
---@field doorControllerID number

---@class DoorAuthHostDB : FileDB
---@field data DoorAuthHostDB.Data
---@overload fun(options: FileDB.Options) : DoorAuthHostDB
local DoorAuthHostDB = FileDB:extend()

function DoorAuthHostDB:DeserializeData(data)
    return {
        permittedUsers = data.permittedUsers,
        permittedPositions = GVector:DeserializeList(data.permittedPositions),
        doorControllerID = data.doorControllerID
    }
end

function DoorAuthHostDB:SerializeData()
    return {
        permittedUsers = self.data.permittedUsers,
        permittedPositions = GVector:SerializeList(self.data.permittedPositions),
        doorControllerID = self.data.doorControllerID
    }
end

---@class DoorAuthHost.Options : GAuth.AuthHost.Options
---@field doorControllerID number

---@class DoorAuthHost : GAuth.AuthHost
---@overload fun(options: DoorAuthHost.Options) : DoorAuthHost
local DoorAuthHost = GAuth.AuthHost:extend()

---@param options DoorAuthHost.Options
function DoorAuthHost:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    DoorAuthHost.super.new(self, options)
    self.doorControllerID = options.doorControllerID
    self.db = DoorAuthHostDB {file = "doorauthhost.db"}
    self:Init()
end

function DoorAuthHost:Init()
    if not self.db.data.permittedUsers then
        self.permittedUsers = TermUtil:ReadList("Enter permitted users (comma-separated):")
    end
    if not self.db.data.permittedPositions then
        local positions = {}
        for i = 1, 4 do
            local pos = TermUtil:ReadGVector(f("Enter Scan Position #%d:", i))
            table.insert(positions, pos)
        end
        self.permittedPositions = positions
    end

    if not self.db.data.doorControllerID then
        self.db.data.doorControllerID = TermUtil:ReadNumber("Enter Door Controller ID:")
    end

    term.clear()
    term.setCursorPos(1, 1)

    print("Door Auth Host Initiated..")

    self.db:Persist()
end

function DoorAuthHost:OpenDoors()
    rednet.send(self.doorControllerID, DoorController.PROTOCOL.DOOR_OPEN)
end
