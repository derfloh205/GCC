local Object = require("GTurtle/classics")
local TU = require("GTurtle/table_utils")
local GNAV = require("GTurtle/gnav")
local expect = require("cc.expect")
local expect, field = expect.expect, expect.field

---@class GTurtle
local GTurtle = {}

---@enum GTurtle.TYPES
GTurtle.TYPES = {
    BASE = "BASE",
    RUBBER = "RUBBER"
}

---@class GTurtle.Base : Object
GTurtle.Base = Object:extend()

function GTurtle.Base:new(options)
    expect(1, options, "table")
    field(options, "name", "string")
    field(options, "fuelWhiteList", "table", "nil")
    field(options, "minimumFuel", "number", "nil")
    field(options, "term", "table", "nil")
    options = options or {}
    self.name = options.name
    self.fuelWhiteList = options.fuelWhiteList
    self.minimumFuel = options.minimumFuel or 100
    self.type = GTurtle.TYPES.BASE
    self.term = options.term or term
    self.log = options.log or false
    if self.log then
        self.logTerm = options.logTerm or term
        self.logTerm:Clear()
    end

    term:redirect(self.term)
    self.term:Clear()

    self.nav = GNAV.GridNav(self, vector.new(0, 0, 0))

    os.setComputerLabel(self.name)
    self:Log("Initiating Turtle: " .. self.name)
end

function GTurtle.Base:Log(text)
    if not self.log then
        return
    end
    self.logTerm.write(text)
    local _, y = self.logTerm:getCursorPos()
    self.logTerm.setCursorPos(1, y + 1)
end

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

    return TU:tContains(self.fuelWhiteList, item.name)
end

function GTurtle.Base:Refuel()
    local fuel = turtle.getFuelLevel()
    self:Log("Fuel Check: " .. fuel .. "/" .. self.minimumFuel)
    if fuel >= self.minimumFuel then
        return
    end

    local selectionID = turtle.getSelectedSlot()
    -- search for fuel
    for i = 1, 16 do
        local isFuel = self:IsFuel(i)

        if isFuel then
            while true do
                local ok = turtle.refuel(1)
                if self.minimumFuel <= turtle.getFuelLevel() then
                    return
                end
                if not ok then
                    break
                end
            end
        end
    end

    self:Log("No Fuel Available")
end

function GTurtle.Base:Move(dir)
    expect(1, dir, "string")
    local moved, err
    if dir == GNAV.MOVE.F then
        moved, err = turtle.forward()
    elseif dir == GNAV.MOVE.B then
        moved, err = turtle.back()
    elseif dir == GNAV.MOVE.U then
        moved, err = turtle.up()
    elseif dir == GNAV.MOVE.D then
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

function GTurtle.Base:MoveUntilBlocked(dir)
    local blocked
    repeat
        blocked = self:Move(dir)
    until blocked
end

function GTurtle.Base:ExecuteMovement(path)
    expect(1, path, "string")

    path:gsub(
        ".",
        function(dir)
            if dir == GNAV.TURN.L or dir == GNAV.TURN.R then
                self:Turn(dir)
            else
                self:Move(dir)
            end
        end
    )
end

function GTurtle.Base:Turn(dir)
    expect(1, dir, "string")

    local turned, err
    if dir == GNAV.TURN.L then
        turned, err = turtle.turnLeft()
    elseif dir == GNAV.TURN.R then
        turned, err = turtle.turnRight()
    end

    if turned then
        self.nav:OnTurn(dir)
    else
        self:Log("Turning Blocked: " .. tostring(err))
    end
end

function GTurtle.Base:ScanBlocks()
    local isBlock, data
    local blockData = {}
    isBlock, data = turtle.inspect()
    blockData[GNAV.MOVE.F] = isBlock and data
    isBlock, data = turtle.inspectUp()
    blockData[GNAV.MOVE.U] = isBlock and data
    isBlock, data = turtle.inspectDown()
    blockData[GNAV.MOVE.D] = isBlock and data
    return blockData
end

function GTurtle.Base:VisualizeGrid()
    -- visualize on redirected terminal (or current if there is none)
    term.clear()
    term.setCursorPos(1, 1)
    print(self.nav.gridMap:GetGridString())
end

---@class GTurtle.Rubber : GTurtle.Base
GTurtle.Rubber = GTurtle.Base:extend()

function GTurtle.Rubber:new(options)
    self.super.new(self, options)
    self.type = GTurtle.TYPES.RUBBER
end

return GTurtle
