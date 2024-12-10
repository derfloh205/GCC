local TUtil = require("GCC/Util/tutil")
local TNav = require("GCC/GTurtle/tnav")
local GNAV = require("GCC/GNav/gnav")
local TNet = require("GCC/GTurtle/tnet")
local GState = require("GCC/Util/gstate")
local f = string.format

---@class GTurtle
local GTurtle = {}

---@enum GTurtle.TYPES
GTurtle.TYPES = {
    BASE = "BASE",
    RUBBER = "RUBBER"
}

---@class GTurtle.TurtleData
---@field data table
---@field id number

---@class GTurtle.Base.Options : GState.StateMachine.Options
---@field name string
---@field fuelWhitelist? string[]
---@field fuelBlacklist? string[]
---@field minimumFuel? number
---@field term? table
---@field visualizeGridOnMove? boolean
---@field initialHead? GNAV.HEAD
---@field avoidUnknown? boolean
---@field avoidAllBlocks? boolean otherwise the turtle will dig its way
---@field digBlacklist? string[] if not all blocks are avoided it uses the digBlacklist
---@field cacheGrid? boolean
---@field fenceCorners? GVector[]

---@class GTurtle.Base : GState.StateMachine
---@overload fun(options: GTurtle.Base.Options) : GTurtle.Base
GTurtle.Base = GState.StateMachine:extend()

---@param options GTurtle.Base.Options
function GTurtle.Base:new(options)
    options = options or {}
    self.id = os.getComputerID()
    self.name = f("%s[%d]", options.name, self.id)
    options.logFile = f("GTurtle[%d].log", self.id)
    ---@diagnostic disable-next-line: redundant-parameter
    GTurtle.Base.super.new(self, options)
    os.setComputerLabel(self.name)
    self.digBlacklist = options.digBlacklist
    self.avoidAllBlocks = options.avoidAllBlocks == nil or options.avoidAllBlocks -- -> defaults to true
    self.fuelWhitelist = options.fuelWhitelist
    self.fuelBlacklist = options.fuelBlacklist
    self.visualizeGridOnMove = options.visualizeGridOnMove
    self.minimumFuel = options.minimumFuel or 100
    self.tdFile = f("%d_td.json", self.id)
    ---@type GTurtle.TurtleData
    self.turtleData = self:LoadTurtleData()
    ---@type GTurtle.TYPES
    self.type = GTurtle.TYPES.BASE
    self.term = options.term or term
    options.avoidUnknown = options.avoidUnknown or false

    self:Refuel()

    if term ~= self.term then
        term:redirect(self.term)
    end
    self.term.clear()
    self.term.setCursorPos(1, 1)
    self.cacheGrid = options.cacheGrid or false
    self.gridFile = f("%d_grid.json", self.id)

    self.tnav =
        TNav.GridNav(
        {
            gTurtle = self,
            avoidUnknown = options.avoidUnknown,
            avoidAllBlocks = self.avoidAllBlocks,
            blockBlacklist = self.digBlacklist,
            gridFile = self.cacheGrid and self.gridFile,
            fenceCorners = options.fenceCorners
        }
    )
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

---@return GTurtle.TurtleData turtleData
function GTurtle.Base:LoadTurtleData()
    if self.tdFile and fs.exists(self.tdFile) then
        local file = fs.open(self.tdFile, "r")
        local fileData = textutils.unserialiseJSON(file.readAll())
        fileData.data = self:DeserializeTurtleData(fileData.data)
        file.close()
        return fileData
    else
        return {
            id = self.id,
            data = {}
        }
    end
end

--- to be overridden by child turtle types
---@param data table
---@return table
function GTurtle.Base:DeserializeTurtleData(data)
    return data
end

--- to be overridden by child turtle types
---@param data table
---@return table
function GTurtle.Base:SerializeTurtleData(data)
    return data
end

function GTurtle.Base:WriteTurtleData()
    if self.turtleData and self.tdFile then
        local file = fs.open(self.tdFile, "w")
        local writeData = {
            id = self.turtleData.id,
            data = self:SerializeTurtleData(self.turtleData.data)
        }
        file.write(textutils.serialiseJSON(writeData))
        file.close()
    end
end

---@return table<number, table>
function GTurtle.Base:GetInventoryItems()
    local itemMap = {}
    for i = 1, 16 do
        itemMap[i] = turtle.getItemDetail(i)
    end
    return itemMap
end

---@param name string
---@return number? slotID
---@return number? amount
function GTurtle.Base:GetInventoryItem(name)
    local itemMap = self:GetInventoryItems()
    for slot, itemData in pairs(itemMap) do
        if itemData and name == itemData.name then
            return slot, itemData.count
        end
    end

    return
end

---@param name string
---@param requestedCount number? if not set get all
function GTurtle.Base:SuckFromChest(name, requestedCount)
    local success, err
    repeat
        success, err = turtle.suck()
        local hasItem, itemCount = self:GetInventoryItem(name)
        local enoughItems = not requestedCount or (requestedCount <= itemCount)
        local sufficient = hasItem and enoughItems
    until not success or sufficient

    return success, err
end

---@param itemNames string[]
function GTurtle.Base:DropExcept(itemNames)
    local selectedSlotID = turtle.getSelectedSlot()
    local dropItems =
        TUtil:Filter(
        self:GetInventoryItems(),
        function(itemData)
            return not TUtil:tContains(itemNames, itemData.name)
        end,
        true
    )

    for slotID, _ in pairs(dropItems) do
        turtle.select(slotID)
        turtle.drop()
    end
    turtle.select(selectedSlotID)
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

    if self.fuelBlacklist then
        return not TUtil:tContains(self.fuelBlacklist, itemData.name)
    end

    if not self.fuelWhitelist then
        return true
    end

    return TUtil:tContains(self.fuelWhitelist, itemData.name)
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

---@param dir GNAV.DIR
---@return boolean success
---@return string? errormsg
function GTurtle.Base:Move(dir)
    self:FLog("Move: %s", dir)
    local moved, err
    if dir == GNAV.DIR.F then
        moved, err = turtle.forward()
    elseif dir == GNAV.DIR.B then
        moved, err = turtle.back()
    elseif dir == GNAV.DIR.U then
        moved, err = turtle.up()
    elseif dir == GNAV.DIR.D then
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

---@param dir GNAV.DIR
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
            local success, err = self:Turn(move)
            if not success then
                return false, err
            end
        else
            local success, err = self:Move(move)
            if not success then
                return false, err
            end
        end
    end

    return true
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

function GTurtle.Base:IsBlockBlacklistedForDigging(blockData)
    if not blockData or not self.digBlacklist then
        return false
    end
    return TUtil:tContains(self.digBlacklist, blockData.name)
end

--- U | D | F
---@param dir GNAV.DIR
---@param side? "left" | "right"
---@return boolean success
---@return string? err
function GTurtle.Base:Dig(dir, side)
    local success, err

    local _, digBlock = self:Scan(dir)

    local isBlacklisted = self:IsBlockBlacklistedForDigging(digBlock)

    if isBlacklisted then
        return false, f("Not Digging: %s", (digBlock and digBlock.name))
    end

    if dir == GNAV.DIR.F then
        success, err = turtle.dig(side)
    elseif dir == GNAV.DIR.U then
        success, err = turtle.digUp(side)
    elseif dir == GNAV.DIR.D then
        success, err = turtle.digDown(side)
    end

    if success then
        self.tnav:UpdateSurroundings()
        self.tNetClient:SendGridMap()
        return true
    else
        self:FLog("Could not dig: %s", err)
        return false, err
    end
end

---@return table<GNAV.DIR, table?>
function GTurtle.Base:ScanBlocks()
    local scanData = {}
    local isF, dataF = self:Scan(GNAV.DIR.F)
    local isU, dataU = self:Scan(GNAV.DIR.U)
    local isD, dataD = self:Scan(GNAV.DIR.D)
    scanData[GNAV.DIR.F] = isF and dataF
    scanData[GNAV.DIR.U] = isU and dataU
    scanData[GNAV.DIR.D] = isD and dataD
    return scanData
end

---@param dir GNAV.DIR
---@return boolean isBlock
---@return table? blockData
function GTurtle.Base:Scan(dir)
    if dir == GNAV.DIR.F then
        return turtle.inspect()
    elseif dir == GNAV.DIR.U then
        return turtle.inspectUp()
    elseif dir == GNAV.DIR.D then
        return turtle.inspectDown()
    end

    return false, nil
end

function GTurtle.Base:VisualizeGrid()
    -- visualize on redirected terminal (or current if there is none)
    term.clear()
    term.setCursorPos(1, 1)
    local gridString = self.tnav.gridMap:GetCenteredGridString(self.tnav.currentGN.pos, 10)
    print(gridString)
end

---@param reqHead GNAV.HEAD
function GTurtle.Base:TurnToHead(reqHead)
    local head = self.tnav.head
    if head == reqHead then
        return
    end

    if reqHead == GNAV.HEAD.N then
        if head == GNAV.HEAD.W then
            self:Turn("R")
        elseif head == GNAV.HEAD.E then
            self:Turn("L")
        elseif head == GNAV.HEAD.S then
            self:Turn("R")
            self:Turn("R")
        end
    elseif reqHead == GNAV.HEAD.S then
        if head == GNAV.HEAD.W then
            self:Turn("L")
        elseif head == GNAV.HEAD.E then
            self:Turn("R")
        elseif head == GNAV.HEAD.N then
            self:Turn("R")
            self:Turn("R")
        end
    elseif reqHead == GNAV.HEAD.W then
        if head == GNAV.HEAD.N then
            self:Turn("L")
        elseif head == GNAV.HEAD.S then
            self:Turn("R")
        elseif head == GNAV.HEAD.E then
            self:Turn("R")
            self:Turn("R")
        end
    elseif reqHead == GNAV.HEAD.E then
        if head == GNAV.HEAD.N then
            self:Turn("R")
        elseif head == GNAV.HEAD.S then
            self:Turn("L")
        elseif head == GNAV.HEAD.W then
            self:Turn("R")
            self:Turn("R")
        end
    end
end

---@param goalPos GVector
---@param flat? boolean only allow navigation in current Z
function GTurtle.Base:NavigateToPosition(goalPos, flat)
    self:FLog("Trying to navigate to position: %s", goalPos)
    local function RecalculatePath()
        -- Recalculate Path Based on new Grid Info
        self:FLog("Recalculating Path: %s", path)
        local path = self.tnav:CalculatePathToPosition(goalPos, flat)
        if path then
            self.tnav:SetActivePath(path)
        else
            self:Log("Navigation: No Path Available After Recalculation")
        end
        return path
    end
    local path = self.tnav:CalculatePathToPosition(goalPos, flat)
    self:FLog("Calculated Path:\n%s", path)
    if path then
        self.tnav:SetActivePath(path)
        repeat
            local nextMove, isGoal = self.tnav:GetNextMoveAlongPath()
            if nextMove then
                if GNAV.HEAD[nextMove] then
                    -- dig first if needed and allowed
                    self:TurnToHead(nextMove)
                else
                    if not self.avoidAllBlocks then
                        local success, err = self:Dig(nextMove)
                        if not success then
                            self:Log("Navigating: Could not dig")
                            self:FLog("- %s", err)
                            path = RecalculatePath()
                            if not path then
                                return false
                            end
                        end
                    end
                    --self:FLog("Navigating: %s", nextMove)
                    local success = self:Move(nextMove)
                    if not success then
                        path = RecalculatePath()
                        if not path then
                            return false
                        end
                    end
                end
            end
        until isGoal
        self:FLog("Arrived on Target Position")
        return true
    else
        self:Log("Navigation: No Path Available")
        return false
    end
end

function GTurtle.Base:NavigateToInitialPosition()
    self:NavigateToPosition(self.tnav.initGN.pos)
end

function GTurtle.Base:INIT()
    self:FLog("Initiating Basic Turtle: %s", self.name)
    self:SetState(GState.STATE.EXIT)
end

return GTurtle
