local SUtil = require("GCC/Util/sutil")
local GVector = require("GCC/GNav/gvector")
local f = string.format
--- Terminal Utils
---@class TermUtil
local TermUtil = {}

---@param prompt string
---@return GVector gvector
function TermUtil:ReadGVector(prompt)
    local split = {}
    local x, y, z
    repeat
        print(prompt .. "\nFormat: 'x,y,z'")
        local posString = read()
        split = SUtil:Split(posString, ",")
        x, y, z = tonumber(split[1]), tonumber(split[2]), tonumber(split[3])
    until type(x) == "number" and type(y) == "number" and type(z) == "number"

    return GVector(x, y, z)
end

---@param prompt string
---@return boolean confirmed
function TermUtil:ReadConfirmation(prompt)
    print(prompt .. " (Y/n)")
    local response = read()
    if response == "y" or response == "Y" or response == "" then
        return true
    else
        return false
    end
end

---@param prompt string
---@return number
function TermUtil:ReadNumber(prompt)
    local number
    repeat
        print(prompt)
        number = tonumber(read())
    until type(number) == "number"
    return number
end

function TermUtil:ReadString(prompt)
    print(prompt)
    return read()
end

function TermUtil:ReadList(prompt)
    print(prompt)
    local list = read()
    return SUtil:Split(list, ",")
end

return TermUtil
