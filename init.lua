local Object = require("GTurtle/classics")
local TU = require("GTurtle/table_utils")
local GNAV = require("GTurtle/nav")
local expect = require("cc.expect")
local expect, field = expect.expect, expect.field

local GTurtle = {}

GTurtle.TYPES = {
    BASE = "BASE",
    RUBBER = "RUBBER"
}

GTurtle.Base = Object:extend()

function GTurtle.Base:new(options)
    expect(1, options, "table")
    field(options, "name", "string")
    field(options, "fuelWhiteList", "table", "nil")
    field(options, "minimumFuel", "number", "nil")
    options = options or {}
    self.name = options.name
    self.fuelWhiteList = options.fuelWhiteList
    self.minimumFuel = options.minimumFuel or 100
    self.type = GTurtle.TYPES.BASE

    self.nav = GNAV.GridNav(vector.new(0, 0, 0))

    os.setComputerLabel(self.name)
    print("Starting: " .. self.name)
end

function GTurtle.Base:IsFuel(i)
    local isFuel = turtle.refuel(0)

    if not isFuel then return false end

    local item = turtle.getItemDetail(i)

    if not item then return false end

    if not self.fuelWhiteList then return true end

    return TU:tContains(self.fuelWhiteList, item.name)
end

function GTurtle.Base:Refuel()
    local fuel = turtle.getFuelLevel()
    print("Fuel Check: " .. fuel .. "/" .. self.minimumFuel)
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

    print("No Fuel Available")
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
        self.nav:Move(dir)
    else
        print("Movement Blocked: " .. tostring(err))
    end
end

function GTurtle.Base:ExecuteMovement(path)
    expect(1, path, "string")

    path:gsub(".", function(dir) 
        if dir == GNAV.TURN.L or dir == GNAV.TURN.R then
            self:Turn(dir)
        else
            self:Move(dir)
        end
    end)
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
        self.nav:Turn(dir)
    else
        print("Turning Blocked: " .. tostring(err))
    end
end

GTurtle.Rubber = GTurtle.Base:extend()

function GTurtle.Rubber:new(options)
    self.super.new(self, options)
    self.type = GTurtle.TYPES.RUBBER
end

return GTurtle
