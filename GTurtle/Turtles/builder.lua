local GTurtle = require("GCC/GTurtle/gturtle")
local GState = require("GCC/Util/gstate")
local GNAV = require("GCC/GNav/gnav")
local TUtil = require("GCC/Util/tutil")
local TermUtil = require("GCC/Util/termutil")
local GVector = require("GCC/GNav/gvector")
local CONST = require("GCC/Util/const")
local f = string.format

---@class GTurtle.BuilderTurtle.Options : GTurtle.Base.Options

---@class GTurtle.BuilderTurtle : GTurtle.Base
local BuilderTurtle = GTurtle.Base:extend()

---@class GTurtle.BuilderTurtle.STATE : GState.STATE
BuilderTurtle.STATE = {}
TUtil:Inject(BuilderTurtle.STATE, GState.STATE)

---@param options GTurtle.BuilderTurtle.Options
function BuilderTurtle:new(options)
    options = options or {}
    options.avoidAllBlocks = true
    options.fuelWhitelist = {CONST.ITEMS.RUBBER_WOOD, CONST.ITEMS.COAL, CONST.ITEMS.LAVA_BUCKET}
    options.dbFile = options.dbFile or "builderTurtle.db"
    ---@diagnostic disable-next-line: redundant-parameter
    self.super.new(self, options)
    self.type = GTurtle.TYPES.BUILDER
end

function BuilderTurtle:BuildPlatform(block, sizeX)
    local gridMap = self.db.data.gridMap
    local midGN = self.tnav.currentGN

    local function buildAndMove()
        local slotID = self:GetInventoryItem(block)
        turtle.placeDown()
    end
end
