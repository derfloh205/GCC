---@class GCC.Util.TUtil
local TUtil = {}

---@param table table
---@param element any
function TUtil:tContains(table, element)
    for _, value in ipairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

--- Inject tableB into tableA
---@param tableA table
---@param tableB table
function TUtil:Inject(tableA, tableB)
    for k, v in pairs(tableB) do
        tableA[k] = v
    end
end

return TUtil
