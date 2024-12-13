---@class Const
local CONST = {}

---@class BlockState.RubberWood
---@field resinfacing "north" | "east" | "south" | "west"
---@field axis "x" | "y" | "z"
---@field resin boolean
---@field collectable boolean

---@class BlockData.RubberWood : BlockData
---@field state BlockState.RubberWood

---@class BlockState

---@class BlockData
---@field name string
---@field metadata number
---@field state? BlockState

CONST.ITEMS = {
    -- blocks
    QUARK_CHEST = "quark:custom_chest",
    RUBBER_WOOD = "ic2:blockrubwood",
    -- loot / drops
    RUBBER_SAPLINGS = "ic2:blockrubsapling",
    RUBBER_LEAVES = "ic2:leaves",
    RESIN = "ic2:itemharz",
    COAL = "minecraft:coal", -- also charcoal
    BONE_MEAL = "minecraft:dye", -- ??
    LAVA_BUCKET = "minecraft:lava_bucket"
}

CONST.TOOLS = {
    ELECTRIC_TREE_TAP = "ic2:itemtreetapelectric",
    TREE_TAP = "ic2:itemtreetap"
}

CONST.CHEST_BLOCKS = {
    "quark:custom_chest"
}

CONST.DEFAULT_FUEL_ITEMS = {
    CONST.ITEMS.COAL
}

return CONST
