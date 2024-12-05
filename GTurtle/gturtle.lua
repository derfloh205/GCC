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
---@field fuelWhiteList? string[]
---@field minimumFuel? number
---@field term? table
---@field visualizeGridOnMove? boolean
---@field initialHead? GTurtle.TNAV.HEAD
---@field avoidUnknown? boolean

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
    options.avoidUnknown = options.avoidUnknown or false

    self:Refuel()

    self:Log(f("Initiating..."))

    if term ~= self.term then
        term:redirect(self.term)
    end
    self.term.clear()
    self.term.setCursorPos(1, 1)

    self.tnav = TNav.GridNav({gTurtle = self, avoidUnknown = options.avoidUnknown})
    if self.tnav.gpsEnabled then
        self:Log(f("Using GPS Position: %s", tostring(self.tnav.currentGN.pos)))
    end

    if not self.tnav.head then
        error("Turtle not able to determine initial heading")
    end

    self.tNetClient =
        TNet.TurtleHostClient {
        gTurtle = self,
        log = options.log,
        clearLog = options.clearLog,
        logFile = f("TurtleHost[%d].log", self.id)
    }
end

---@return table<number, table>
function GTurtle.Base:GetInventoryItems()
    local itemMap = {}
    for i = 1, 16 do
        itemMap[i] = turtle.getItemDetail(i)
    end
    return itemMap
end

---@return boolean isFuelSelected
function GTurtle.Base:SelectFuel()
    local itemMap = self:GetInventoryItems()
    local preSlotID = turtle.getSelectedSlot()

    for slotID, itemData in pairs(itemMap) do
        turtle.select(slotID)
        if self:IsFuel(itemData) then
            return true
        end
    end

    if preSlotID ~= turtle.getSelectedSlot() then
        turtle.select(preSlotID)
    end

    return false
end

---@param itemData table
---@return boolean isFuel
function GTurtle.Base:IsFuel(itemData)
    local isFuel = turtle.refuel(0)

    if not isFuel then
        return false
    end

    if not self.fuelWhiteList then
        return true
    end

    return TUtil:tContains(self.fuelWhiteList, itemData.name)
end

---@return boolean refueled
function GTurtle.Base:Refuel()
    local fuel = turtle.getFuelLevel()
    self:Log(f("Fuel Check: %d/%d", fuel, self.minimumFuel))
    if fuel >= self.minimumFuel then
        return true
    end

    local preSlotID = turtle.getSelectedSlot()
    local fuelFound = self:SelectFuel()

    if not fuelFound then
        self:Log("No valid fuel in inventory..")
        return false
    end

    repeat
        local ok = turtle.refuel(1)
    until not ok or self.minimumFuel <= turtle.getFuelLevel()

    turtle.select(preSlotID)

    fuel = turtle.getFuelLevel()
    self:FLog("Refueled: %d/%d", fuel, self.minimumFuel)

    return self.minimumFuel <= fuel
end

---@param dir GTurtle.TNAV.MOVE
---@return boolean success
---@return string? errormsg
function GTurtle.Base:Move(dir)
    self:FLog("Move: %s", dir)
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
        self.tNetClient:SendPosUpdate()
        if self.visualizeGridOnMove then
            self:VisualizeGrid()
        end
        self.tNetClient:SendGridMap()
        return true
    else
        self:Log(f("- %s", tostring(err)))
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
---@return boolean success
---@return string? err
function GTurtle.Base:ExecuteMovement(path)
    for i = 1, #path do
        local move = string.sub(path, i, i)
        if TNav.TURN[move] then
            return self:Turn(move)
        else
            return self:Move(move)
        end
    end
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
        self.tNetClient:SendPosUpdate()
        if self.visualizeGridOnMove then
            self:VisualizeGrid()
        end
        self.tNetClient:SendGridMap()
        return true
    else
        self:FLog("Turning Blocked: %s", err)
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
    local gridString = self.tnav.gridMap:GetCenteredGridString(self.tnav.currentGN.pos, 10)
    print(gridString)
end

---@param goalPos Vector
function GTurtle.Base:NavigateToPosition(goalPos)
    local path = self.tnav:CalculatePathToPosition(goalPos)
    self:FLog("Calculated Path:\n%s", path)
    if path then
        self.tnav:SetActivePath(path)
        repeat
            local nextMove, isGoal = self.tnav:GetNextMoveAlongPath()
            if nextMove then
                self:Log(f("Navigating: %s", tostring(nextMove)))
                local success = self:ExecuteMovement(nextMove)
                if not success then
                    -- Recalculate Path Based on new Grid Info
                    self:Log("Recalculating Path..")
                    path = self.tnav:CalculatePathToPosition(goalPos)
                    if path then
                        self.tnav:SetActivePath(path)
                    else
                        self:Log("Navigation: No Path Available After Recalculation")
                        return false
                    end
                end
            end
        until isGoal
        self:Log(f("Arrived on Initial Position"))
        return true
    else
        self:Log("Navigation: No Path Available")
        return false
    end
end

function GTurtle.Base:NavigateToInitialPosition()
    self:NavigateToPosition(self.tnav.initGN.pos)
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
