local TUtil = require("GCC/Util/tutil")
local TNav = require("GCC/GTurtle/tnav")
local TNet = require("GCC/GTurtle/tnet")
local GLogAble = require("GCC/Util/glog")
local VUtil = require("GCC/Util/vutil")
local f = string.format

---@class GTurtle
local GTurtle = {}

---@enum GTurtle.TYPES
GTurtle.TYPES = {
    BASE = "BASE",
    RUBBER = "RUBBER"
}

---@class GTurtle.Base.Options : GLogAble.Options
---@field name string
---@field turtleHostID number
---@field fuelWhiteList? string[]
---@field minimumFuel? number
---@field term? table
---@field visualizeGridOnMove? boolean

---@class GTurtle.Base : GLogAble
---@overload fun(options: GTurtle.Base.Options) : GTurtle.Base
GTurtle.Base = GLogAble:extend()

---@param options GTurtle.Base.Options
function GTurtle.Base:new(options)
    options = options or {}
    self.id = os.getComputerID()
    self.name = f("%s[%d]", options.name, self.id)
    options.logFile = f("GTurtle[%d].log", self.id)
    ---@diagnostic disable-next-line: redundant-parameter
    GTurtle.Base.super.new(self, options)
    os.setComputerLabel(self.name)
    self.fuelWhiteList = options.fuelWhiteList
    self.visualizeGridOnMove = options.visualizeGridOnMove
    self.minimumFuel = options.minimumFuel or 100
    ---@type GTurtle.TYPES
    self.type = GTurtle.TYPES.BASE
    self.term = options.term or term

    self:Log(f("Initiating Turtle: %s", self.name))

    if term ~= self.term then
        term:redirect(self.term)
    end
    self.term.clear()
    self.term.setCursorPos(1, 1)

    self.tNetClient =
        TNet.TurtleHostClient {
        gTurtle = self,
        log = options.log,
        clearLog = options.clearLog,
        logFile = f("TurtleHost[%d].log", self.id)
    }

    self.tnav = TNav.GridNav({gTurtle = self})
    if self.tnav.gpsEnabled then
        self:Log(f("Using GPS Position: %s", tostring(self.tnav.pos)))
    end
end

---@param i number slotIndex
---@return boolean isFuel
function GTurtle.Base:IsFuel(i)
    local isFuel = turtle.refuel(0)

    if not isFuel then
        return false
    end

    local item = turtle.getItemDetail(i)

    if not item then
        return false
    end

    if not self.fuelWhiteList then
        return true
    end

    return TUtil:tContains(self.fuelWhiteList, item.name)
end

---@return boolean refueled
function GTurtle.Base:Refuel()
    local fuel = turtle.getFuelLevel()
    self:Log(f("Fuel Check: %d/%d", fuel, self.minimumFuel))
    if fuel >= self.minimumFuel then
        return true
    end

    -- search for fuel
    for i = 1, 16 do
        local isFuel = self:IsFuel(i)

        if isFuel then
            while true do
                local ok = turtle.refuel(1)
                if self.minimumFuel <= turtle.getFuelLevel() then
                    return true
                end
                if not ok then
                    break
                end
            end
        end
    end

    self:Log("No Fuel Available")
    return false
end

---@param dir GTurtle.TNAV.MOVE
---@return boolean success
---@return stringlib? errormsg
function GTurtle.Base:Move(dir)
    local moved, err
    if dir == TNav.MOVE.F then
        moved, err = turtle.forward()
    elseif dir == TNav.MOVE.B then
        moved, err = turtle.back()
    elseif dir == TNav.MOVE.U then
        moved, err = turtle.up()
    elseif dir == TNav.MOVE.D then
        moved, err = turtle.down()
    end

    if moved then
        self.tnav:OnMove(dir)
        if self.visualizeGridOnMove then
            self:VisualizeGrid()
        end
        return true
    else
        self:Log(f("Movement Blocked: %s", tostring(err)))
        return false, err
    end
end

---@param dir GTurtle.TNAV.MOVE
function GTurtle.Base:MoveUntilBlocked(dir)
    local blocked
    repeat
        blocked = self:Move(dir)
    until blocked
end

---@param path string e.g. "FBLRUD"
function GTurtle.Base:ExecuteMovement(path)
    path:gsub(
        ".",
        function(dir)
            if dir == TNav.TURN.L or dir == TNav.TURN.R then
                self:Turn(dir)
            else
                self:Move(dir)
            end
        end
    )
end

---@param turn GTurtle.TNAV.TURN
---@return boolean success
---@return string? errormsg
function GTurtle.Base:Turn(turn)
    local turned, err
    if turn == TNav.TURN.L then
        turned, err = turtle.turnLeft()
    elseif turn == TNav.TURN.R then
        turned, err = turtle.turnRight()
    end

    if turned then
        self.tnav:OnTurn(turn)
        if self.visualizeGridOnMove then
            self:VisualizeGrid()
        end
        return true
    else
        self:Log(f("Turning Blocked: %s", tostring(err)))
        return false, err
    end
end

---@return table<GTurtle.TNAV.MOVE, table?>
function GTurtle.Base:ScanBlocks()
    local scanData = {}
    local isF, dataF = turtle.inspect()
    local isU, dataU = turtle.inspectUp()
    local isD, dataD = turtle.inspectDown()
    scanData[TNav.MOVE.F] = isF and dataF
    scanData[TNav.MOVE.U] = isU and dataU
    scanData[TNav.MOVE.D] = isD and dataD
    return scanData
end

function GTurtle.Base:VisualizeGrid()
    -- visualize on redirected terminal (or current if there is none)
    term.clear()
    term.setCursorPos(1, 1)
    local gridString = self.tnav.gridMap:GetGridString(self.tnav.pos.z)
    print(gridString)
    self.tNetClient:SendReplace(gridString)
end

---@param goalPos Vector
function GTurtle.Base:NavigateToPosition(goalPos)
    local path = self.tnav:CalculatePathToPosition(goalPos)
    if path then
        self.tnav:SetActivePath(path)
        repeat
            local nextMove = self.tnav:GetNextMoveAlongPath()
            if nextMove then
                self:Log(f("Navigating: %s", tostring(nextMove)))
                self:ExecuteMovement(nextMove)
            end
        until not nextMove
        self:Log(f("Arrived on Initial Position"))
    else
        self:Log("Navigation: No Path Available")
    end
end

function GTurtle.Base:NavigateToInitialPosition()
    self:NavigateToPosition(self.tnav.initPos)
end

---@class GTurtle.Rubber.Options : GTurtle.Base.Options

---@class GTurtle.Rubber : GTurtle.Base
---@overload fun(options: GTurtle.Rubber.Options) : GTurtle.Rubber
GTurtle.Rubber = GTurtle.Base:extend()

---@param options GTurtle.Rubber.Options
function GTurtle.Rubber:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    self.super.new(self, options)
    self.type = GTurtle.TYPES.RUBBER
end

return GTurtle
