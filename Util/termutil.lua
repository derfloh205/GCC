local SUtil = require("GCC/Util/sutil")
---@class TermUtil
local TermUtil = {}

---@param prompt string
---@return Vector vector
function TermUtil:ReadVector(prompt)
    print(prompt .. "\nFormat: 'x,y,z'")
    local split = {}
    repeat
        local posString = read()
        split = SUtil:Split(posString, ",")
    until type(split[1]) == "number" and type(split[2]) == "number" and type(split[3]) == "number"

    return vector.new(split[1], split[2], split[3])
end

---@param prompt string
---@return boolean confirmed
function TermUtil:ReadConfirmation(prompt)
    print(prompt .. " (Y/n)")
    local response = read()
    if response == "y" or response == "Y" or response == "" then
        return false
    else
        return true
    end
end

return TermUtil
