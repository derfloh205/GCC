local Object = require("GTurtle/classics")
local TUtils = require("GTurtle/tutils")
local GNav = require("GTurtle/gnav")

---@class GTurtle
local GTurtle = {}

---@enum GTurtle.TYPES
GTurtle.TYPES = {
    BASE = "BASE",
    RUBBER = "RUBBER"
}

---@class GTurtle.Base.Options
---@field name string
---@field fuelWhiteList? string[]
---@field minimumFuel? number
---@field term? table
---@field logTerm? table
---@field log? boolean

---@class GTurtle.Base : Object
---@overload fun(options: GTurtle.Base.Options) : GTurtle.Base
GTurtle.Base = Object:extend()

---@param options GTurtle.Base.Options
function GTurtle.Base:new(options)
    options = options or {}
    self.name = options.name
    self.fuelWhiteList = options.fuelWhiteList
    self.minimumFuel = options.minimumFuel or 100
    ---@type GTurtle.TYPES
    self.type = GTurtle.TYPES.BASE
    self.term = options.term or term
    self.log = options.log or false
    if self.log then
        self.logTerm = options.logTerm or term
        self.logTerm:Clear()
    end

    term:redirect(self.term)
    self.term:Clear()

    self.nav = GNav.GridNav({gTurtle = self, initPos = vector.new(0, 0, 0)})

    os.setComputerLabel(self.name)
    self:Log("Initiating Turtle: " .. self.name)
end

---@param text string
function GTurtle.Base:Log(text)
    if not self.log then
        return
    end
    self.logTerm.write(text)
    local _, y = self.logTerm:getCursorPos()
    self.logTerm.setCursorPos(1, y + 1)
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

    return TUtils:tContains(self.fuelWhiteList, item.name)
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

---@param dir GNAV.MOVE
---@return boolean success
---@return stringlib? errormsg
function GTurtle.Base:Move(dir)
    local moved, err
    if dir == GNav.MOVE.F then
        moved, err = turtle.forward()
    elseif dir == GNav.MOVE.B then
        moved, err = turtle.back()
    elseif dir == GNav.MOVE.U then
        moved, err = turtle.up()
    elseif dir == GNav.MOVE.D then
        moved, err = turtle.down()
    end

    if moved then
        self.nav:OnMove(dir)
        return true
    else
        self:Log("Movement Blocked: " .. tostring(err))
        return false, err
    end
end

---@param dir GNAV.MOVE
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
            if dir == GNav.TURN.L or dir == GNav.TURN.R then
                self:Turn(dir)
            else
                self:Move(dir)
            end
        end
    )
end

---@param turn GNAV.TURN
---@return boolean success
---@return string? errormsg
function GTurtle.Base:Turn(turn)
    local turned, err
    if turn == GNav.TURN.L then
        turned, err = turtle.turnLeft()
    elseif turn == GNav.TURN.R then
        turned, err = turtle.turnRight()
    end

    if turned then
        self.nav:OnTurn(turn)
        return true
    else
        self:Log("Turning Blocked: " .. tostring(err))
        return false, err
    end
end

---@return table<GNAV.MOVE, table?>
function GTurtle.Base:ScanBlocks()
    local isBlock, data
    local blockData = {}
    isBlock, data = turtle.inspect()
    blockData[GNav.MOVE.F] = isBlock and data
    isBlock, data = turtle.inspectUp()
    blockData[GNav.MOVE.U] = isBlock and data
    isBlock, data = turtle.inspectDown()
    blockData[GNav.MOVE.D] = isBlock and data
    return blockData
end

function GTurtle.Base:VisualizeGrid()
    -- visualize on redirected terminal (or current if there is none)
    term.clear()
    term.setCursorPos(1, 1)
    print(self.nav.gridMap:GetGridString(self.nav.pos.z))
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
