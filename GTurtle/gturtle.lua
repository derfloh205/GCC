local Object = require("GCC/Util/classics")
local TUtil = require("GCC/Util/tutil")
local TNav = require("GCC/GTurtle/turtlenavigation")
local TNet = require("GCC/GTurtle/turtlenet")

---@class GTurtle
local GTurtle = {}

---@enum GTurtle.TYPES
GTurtle.TYPES = {
    BASE = "BASE",
    RUBBER = "RUBBER"
}

---@class GTurtle.Base.Options
---@field name string
---@field turtleHostID number
---@field fuelWhiteList? string[]
---@field minimumFuel? number
---@field term? table
---@field log? boolean
---@field clearLog? boolean
---@field visualizeGridOnMove? boolean

---@class GTurtle.Base : Object
---@overload fun(options: GTurtle.Base.Options) : GTurtle.Base
GTurtle.Base = Object:extend()

---@param options GTurtle.Base.Options
function GTurtle.Base:new(options)
    options = options or {}
    self.name = options.name
    self.id = os.getComputerID()
    self.fuelWhiteList = options.fuelWhiteList
    self.visualizeGridOnMove = options.visualizeGridOnMove
    self.minimumFuel = options.minimumFuel or 100
    ---@type GTurtle.TYPES
    self.type = GTurtle.TYPES.BASE
    self.term = options.term or term
    self.log = options.log or false
    self.logFile = self.name .. "_log.txt"
    if options.clearLog then
        if fs.exists(self.logFile) then
            fs.delete(self.logFile)
        end
    end

    self:Log("Initiating Turtle: " .. self.name)

    if term ~= self.term then
        term:redirect(self.term)
    end
    self.term.clear()
    self.term.setCursorPos(1, 1)

    self.nav = TNav.GridNav({gTurtle = self, initPos = vector.new(0, 0, 0)})
    self.tNetClient = TNet.TurtleHostClient {gTurtle = self}
    os.setComputerLabel(self.name)
end

---@param text string
function GTurtle.Base:Log(text)
    if not self.log then
        return
    end
    local logFile = fs.open(self.logFile, "a")
    logFile.write(string.format("[%s]: %s\n", os.date("%T"), text))
    logFile.close()
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
    self:Log("Fuel Check: " .. fuel .. "/" .. self.minimumFuel)
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
        self.nav:OnMove(dir)
        if self.visualizeGridOnMove then
            self:VisualizeGrid()
        end
        return true
    else
        self:Log("Movement Blocked: " .. tostring(err))
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
        self.nav:OnTurn(turn)
        if self.visualizeGridOnMove then
            self:VisualizeGrid()
        end
        return true
    else
        self:Log("Turning Blocked: " .. tostring(err))
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
    local gridString = self.nav.gridMap:GetGridString(self.nav.pos.z)
    print(gridString)
    self.tNetClient:SendReplace(gridString)
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
