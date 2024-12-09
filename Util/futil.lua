--- File Utils
---@class FUtil
local FUtil = {}

---@param file string
---@return table?
function FUtil:LoadJSON(file)
    if not fs.exists(file) then
        return
    end
    local f = fs.open(file, "r")
    local json = textutils.unserialiseJSON(f.readAll())
    f.close()
    return json
end

---@param file string
---@param data table
function FUtil:WriteJSON(file, data)
    local f = fs.open(file, "w")
    local json = textutils.serialiseJSON(data)
    f.write(json)
    f.close()
end

return FUtil
