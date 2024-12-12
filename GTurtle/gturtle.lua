local TUtil = require("GCC/Util/tutil")
local TNav = require("GCC/GTurtle/tnav")
local GNAV = require("GCC/GNav/gnav")
local TNet = require("GCC/GTurtle/tnet")
local GState = require("GCC/Util/gstate")
local CONST = require("GCC/Util/const")
local f = string.format

---@class GTurtle
local GTurtle = {}

---@enum GTurtle.TYPES
GTurtle.TYPES = {
    BASE = "BASE",
    RUBBER = "RUBBER"
}

---@enum GTurtle.RETURN_CODE
GTurtle.RETURN_CODE = {
    SUCCESS = "SUCCESS",
    FAILURE = "FAILURE",
    BLOCKED = "BLOCKED",
    NO_FUEL = "NO_FUEL",
    NO_PATH = "NO_PATH"
}

---@class GTurtle.TurtleDB
---@field data table
---@field id number

---@class GTurtle.Base.Options : GState.StateMachine.Options
---@field name string
---@field fuelWhitelist? string[]
---@field minimumFuel? number
---@field term? table
---@field visualizeGridOnMove? boolean
---@field initialHead? GNAV.HEAD
---@field avoidUnknown? boolean
---@field avoidAllBlocks? boolean otherwise the turtle will look at digBlacklist and digWhitelist
---@field digBlacklist? string[] if not all blocks are avoided
---@field digWhitelist? string[] if not all blocks are avoided
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
    self.digWhitelist = options.digWhitelist
    self.avoidAllBlocks = options.avoidAllBlocks == nil or options.avoidAllBlocks -- -> defaults to true
    self.fuelWhitelist = options.fuelWhitelist or CONST.DEFAULT_FUEL_ITEMS
    self.visualizeGridOnMove = options.visualizeGridOnMove
    self.minimumFuel = options.minimumFuel or 100
    self.turtleDBFile = f("turtleDB_%d.json", self.id)
    ---@type GTurtle.TurtleDB
    self.turtleDB = self:LoadTurtleDB()
    ---@type GTurtle.TYPES
    self.type = GTurtle.TYPES.BASE
    self.term = options.term or term
    options.avoidUnknown = options.avoidUnknown or false

    if not self:Refuel() then
        self:RequestFuel()
    end

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
            blockWhitelist = self.digWhitelist,
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

---@return GTurtle.TurtleDB turtleDB
function GTurtle.Base:LoadTurtleDB()
    if self.turtleDBFile and fs.exists(self.turtleDBFile) then
        local file = fs.open(self.turtleDBFile, "r")
        local fileData = textutils.unserialiseJSON(file.readAll())
        fileData.data = self:DeserializeTurtleDB(fileData.data)
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
function GTurtle.Base:DeserializeTurtleDB(data)
    return data
end

--- to be overridden by child turtle types
---@param data table
---@return table
function GTurtle.Base:SerializeTurtleDB(data)
    return data
end

function GTurtle.Base:PersistTurtleDB()
    if self.turtleDB and self.turtleDBFile then
        local file = fs.open(self.turtleDBFile, "w")
        local dbData = {
            id = self.turtleDB.id,
            data = self:SerializeTurtleDB(self.turtleDB.data)
        }
        file.write(textutils.serialiseJSON(dbData))
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
---@return GTurtle.RETURN_CODE returnCode
---@return string? err
function GTurtle.Base:SuckFromChest(name, requestedCount)
    local success, err
    repeat
        success, err = turtle.suck()
        local hasItem, itemCount = self:GetInventoryItem(name)
        local enoughItems = not requestedCount or (requestedCount <= itemCount)
        local sufficient = hasItem and enoughItems
    until not success or sufficient

    if success then
        return GTurtle.RETURN_CODE.SUCCESS
    else
        return GTurtle.RETURN_CODE.FAILURE, err
    end
end

function GTurtle.Base:SuckEverythingFromChest()
    local success
    repeat
        success = turtle.suck()
    until not success
end

---@return GTurtle.RETURN_CODE returnCode
---@return string? err
function GTurtle.Base:RefuelFromChest()
    local success, err
    repeat
        success, err = turtle.suck()
        local refueled = self:Refuel()
    until not success or refueled

    if success then
        return GTurtle.RETURN_CODE.SUCCESS
    else
        return GTurtle.RETURN_CODE.FAILURE, err
    end
end

---@param itemNames string[]
---@param keepFuel boolean?
function GTurtle.Base:DropExcept(itemNames, keepFuel)
    local selectedSlotID = turtle.getSelectedSlot()
    local dropItems =
        TUtil:Filter(
        self:GetInventoryItems(),
        function(itemData)
            return not TUtil:tContains(itemNames, itemData.name) or (keepFuel and self:IsFuel(itemData))
        end,
        true
    )

    for slotID, _ in pairs(dropItems) do
        turtle.select(slotID)
        turtle.drop()
    end
    turtle.select(selectedSlotID)
end

---@param itemNames string[]
function GTurtle.Base:DropItems(itemNames)
    local selectedSlotID = turtle.getSelectedSlot()
    local dropItems =
        TUtil:Filter(
        self:GetInventoryItems(),
        function(itemData)
            return TUtil:tContains(itemNames, itemData.name)
        end,
        true
    )

    for slotID, _ in pairs(dropItems) do
        turtle.select(slotID)
        turtle.drop()
    end
    turtle.select(selectedSlotID)
end

---@param itemName string
---@param content? string e.g. text of a sign
---@return boolean placed
function GTurtle.Base:PlaceItem(itemName, content)
    --- find item in inventory and place it
    local prevSlotID = turtle.getSelectedSlot()
    local slotID, _ = self:GetInventoryItem(itemName)
    if slotID then
        turtle.select(slotID)
        turtle.place(content)
        turtle.select(prevSlotID)
        self.tnav:UpdateSurroundings()
        return true
    else
        return false
    end
end

---@param itemName string
---@param content? string e.g. text of a sign
---@return boolean used
function GTurtle.Base:UseItem(itemName, content)
    return self:PlaceItem(itemName, content)
end

---@return boolean isFuelSelected
function GTurtle.Base:SelectFuel()
    local itemMap = self:GetInventoryItems()
    local fuelItems =
        TUtil:Filter(
        itemMap,
        function(itemData)
            return self:IsFuel(itemData)
        end,
        true
    )

    local slotID = next(fuelItems)
    if not slotID then
        return false
    end

    turtle.select(slotID)
    return true
end

---@param itemData table
---@return boolean isFuel
function GTurtle.Base:IsFuel(itemData)
    return TUtil:tContains(self.fuelWhitelist, itemData.name)
end

---@return boolean refueled
function GTurtle.Base:Refuel()
    self:FLog("Fuel Check: %d/%d", turtle.getFuelLevel(), self.minimumFuel)
    if self:HasMinimumFuel() then
        return true
    end

    local preSlotID = turtle.getSelectedSlot()
    local fuelSelected
    repeat
        local fuelSelected = self:SelectFuel()
        if fuelSelected then
            repeat
                local ok = turtle.refuel(1)
            until not ok or self:HasMinimumFuel()
        end
    until not fuelSelected or self:HasMinimumFuel()

    turtle.select(preSlotID)

    if not fuelSelected then
        self:Log("No valid fuel in inventory..")
        return false
    end

    self:FLog("Refueled: %d/%d", turtle.getFuelLevel(), self.minimumFuel)

    return self:HasMinimumFuel()
end

function GTurtle.Base:HasMinimumFuel()
    return turtle.getFuelLevel() >= self.minimumFuel
end

function GTurtle.Base:RequestFuel()
    self:Log("Requesting Manual Refuel..")
    repeat
        term.clear()
        term.setCursorPos(1, 1)
        print(f("Please Insert Fuel: %d / %d", turtle.getFuelLevel(), self.minimumFuel))
        sleep(1)
        local refueled = self:Refuel()
    until refueled
end

---@param itemNames string[]
---@return boolean hasItems
function GTurtle.Base:HasInventoryItems(itemNames)
    local hasItems =
        TUtil:Every(
        self:GetInventoryItems(),
        function(itemData)
            return TUtil:tContains(itemNames, itemData.name)
        end
    )
    return hasItems
end

---@param itemNames string[]
---@return boolean hasOneItem
function GTurtle.Base:HasOneOfInventoryItems(itemNames)
    local hasOneItem =
        TUtil:Some(
        self:GetInventoryItems(),
        function(itemData)
            return TUtil:tContains(itemNames, itemData.name)
        end
    )
    return hasOneItem
end

---@param itemNames string[]
---@param prompt string?
function GTurtle.Base:RequestOneOfItem(itemNames, prompt)
    self:Log("Requesting Item(s)..")
    repeat
        term.clear()
        term.setCursorPos(1, 1)
        print(prompt or f("Please Insert Item:\n- %s", table.concat(itemNames, ", ")))
        sleep(1)
        local hasItem = self:HasOneOfInventoryItems(itemNames)
    until hasItem
end

---@param itemName string
---@param prompt string?
function GTurtle.Base:RequestItem(itemName, prompt)
    self:RequestOneOfItem({itemName}, prompt)
end

---@param dir GNAV.DIR
---@return GTurtle.RETURN_CODE returnCode
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
        self.tNetClient:SendTurtleDataUpdate()
        if self.visualizeGridOnMove then
            self:VisualizeGrid()
        end
        self.tNetClient:SendGridMap()
        return GTurtle.RETURN_CODE.SUCCESS
    else
        self:Log(f("- %s", tostring(err)))
        return GTurtle.RETURN_CODE.BLOCKED, err
    end
end

---@param path string e.g. "FBLRUD"
---@return GTurtle.RETURN_CODE returnCode
---@return string? err
function GTurtle.Base:ExecuteMovement(path)
    for i = 1, #path do
        local move = string.sub(path, i, i)
        if TNav.TURN[move] then
            local success, err = self:Turn(move)
            if success ~= GTurtle.RETURN_CODE.SUCCESS then
                return success, err
            end
        else
            local success, err = self:Move(move)
            if success ~= GTurtle.RETURN_CODE.SUCCESS then
                return success, err
            end
        end
    end

    return GTurtle.RETURN_CODE.SUCCESS
end

---@param turn GTurtle.TNAV.TURN
---@return GTurtle.RETURN_CODE returnCode
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
        self.tNetClient:SendTurtleDataUpdate()
        if self.visualizeGridOnMove then
            self:VisualizeGrid()
        end
        self.tNetClient:SendGridMap()
        return GTurtle.RETURN_CODE.SUCCESS
    else
        self:FLog("Turning Blocked: %s", err)
        return GTurtle.RETURN_CODE.BLOCKED, err
    end
end

---@param blockData table
---@return boolean isBlacklisted
function GTurtle.Base:IsBlockAllowedForDigging(blockData)
    if self.avoidAllBlocks then
        return false
    end

    if not blockData then
        return true
    end

    if self.digBlacklist then
        return not TUtil:tContains(self.digBlacklist, blockData.name)
    end

    if self.digWhitelist then
        return TUtil:tContains(self.digWhitelist, blockData.name)
    end

    return true
end

--- U | D | F
---@param dir GNAV.DIR
---@param side? "left" | "right"
---@return GTurtle.RETURN_CODE returnCode
---@return string? err
function GTurtle.Base:Dig(dir, side)
    local success, err

    local isBlock, digBlock = self:Scan(dir)

    if not isBlock then
        return GTurtle.RETURN_CODE.SUCCESS
    end

    if not self:IsBlockAllowedForDigging(digBlock) then
        return GTurtle.RETURN_CODE.FAILURE, f("Not Digging: %s", (digBlock and digBlock.name))
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
        return GTurtle.RETURN_CODE.SUCCESS
    else
        self:FLog("Could not dig: %s", err)
        return GTurtle.RETURN_CODE.FAILURE, err
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

---@return GTurtle.RETURN_CODE return_code
function GTurtle.Base:TurnToChest()
    return self:TurnToOneOf(CONST.CHEST_BLOCKS)
end

---@param itemName string
---@return GTurtle.RETURN_CODE return_code
function GTurtle.Base:TurnTo(itemName)
    return self:TurnToOneOf({itemName})
end

---@param itemNames string[]
---@return GTurtle.RETURN_CODE return_code
function GTurtle.Base:TurnToOneOf(itemNames)
    -- search for item
    local itemBlocks =
        self.tnav:GetNeighbors(
        true,
        function(gn)
            return gn:IsItemOf(itemNames)
        end
    )

    if #itemBlocks == 0 then
        -- dance once to scan surroundings then try again
        self:ExecuteMovement("RRRR")
        itemBlocks =
            self.tnav:GetNeighbors(
            true,
            function(gn)
                return gn:IsItemOf(itemNames)
            end
        )
    end

    local itemBlockGN = itemBlocks[1]

    if not itemBlockGN then
        return GTurtle.RETURN_CODE.FAILURE
    end

    local relativeHead = self.tnav.currentGN:GetRelativeHeading(itemBlockGN)
    self:TurnToHead(relativeHead)
    return GTurtle.RETURN_CODE.SUCCESS
end

---@param path TNAV.Path
function GTurtle.Base:SetPath(path)
    if path:GetFuelRequirement() > turtle.getFuelLevel() and not self:Refuel() then
        self:RequestFuel()
    end
    self.tnav:SetActivePath(path)
end

---@param goalPos GVector
---@param flat? boolean only allow navigation in current Z
---@return GTurtle.RETURN_CODE returnCode
function GTurtle.Base:NavigateToPosition(goalPos, flat)
    self:FLog("Trying to navigate to position: %s", goalPos)
    local function RecalculatePath()
        -- Recalculate Path Based on new Grid Info
        local path, err = self.tnav:CalculatePathToPosition(goalPos, flat)
        self:FLog("Recalculating Path\n%s", path)
        if path then
            self:SetPath(path)
        else
            self:FLog("No Path Found: %s", err)
        end
        return path
    end
    local path, err = self.tnav:CalculatePathToPosition(goalPos, flat)
    self:FLog("Calculated Path:\n%s", path)

    if path then
        self:SetPath(path)
        repeat
            local nextMove, isGoal = self.tnav:GetNextMoveAlongPath()
            if nextMove then
                if GNAV.HEAD[nextMove] then
                    self:TurnToHead(nextMove)
                else
                    -- dig first if needed and allowed
                    if not self.avoidAllBlocks then
                        if self:Dig(nextMove) ~= GTurtle.RETURN_CODE.SUCCESS then
                            self:Log("Navigating: Could not dig")
                            path = RecalculatePath()
                            if not path then
                                return GTurtle.RETURN_CODE.NO_PATH
                            end
                        end
                    end
                    if self:Move(nextMove) ~= GTurtle.RETURN_CODE.SUCCESS then
                        path = RecalculatePath()
                        if not path then
                            return GTurtle.RETURN_CODE.NO_PATH
                        end
                    end
                end
            end
        until isGoal
        self:FLog("Arrived on Target Position")
        return GTurtle.RETURN_CODE.SUCCESS
    else
        self:FLog("No Path Found: %s", err)
        return GTurtle.RETURN_CODE.NO_PATH
    end
end

---@return GTurtle.RETURN_CODE returnCode
function GTurtle.Base:NavigateToInitialPosition()
    return self:NavigateToPosition(self.tnav.initGN.pos)
end

function GTurtle.Base:INIT()
    self:FLog("Initiating Basic Turtle: %s", self.name)
    self:SetState(GState.STATE.EXIT)
end

function GTurtle.Base:EXIT()
    self.tNetClient:SendTurtleDataUpdate()
    self:Log("Terminating..")
    return false
end

return GTurtle
