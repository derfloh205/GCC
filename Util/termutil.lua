local SUtil = require("GCC/Util/sutil")
local f = string.format
---@class TermUtil
local TermUtil = {}

---@param prompt string
---@return Vector vector
function TermUtil:ReadVector(prompt)
    local split = {}
    local x, y, z
    repeat
        print(prompt .. "\nFormat: 'x,y,z'")
        local posString = read()
        split = SUtil:Split(posString, ",")
        x, y, z = split[1], split[2], split[3]
    until type(x) == "number" and type(y) == "number" and type(z) == "number"

    return vector.new(x, y, z)
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
