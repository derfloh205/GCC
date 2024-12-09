local SUtil = require("GCC/Util/sutil")
local f = string.format
--- Terminal Utils
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
        x, y, z = tonumber(split[1]), tonumber(split[2]), tonumber(split[3])
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

---@param prompt string
---@return number
function TermUtil:ReadNumber(prompt)
    local number
    repeat
        print(prompt)
        number = read()
    until type(number) == "number"
    return number
end

return TermUtil
