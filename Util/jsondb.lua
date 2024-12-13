local Object = require("GCC/Util/classics")

---@class JsonDB.Options
---@field file string

---@class JsonDB : Object
---@field file string
---@field data table
---@overload fun(options: JsonDB.Options):JsonDB
local JsonDB = Object:extend()

function JsonDB:new(options)
    options = options or {}
    self.file = options.file
    self.data = {}
    self:Load()
end

function JsonDB:Load()
    if not self.file then
        error("JsonDB: No file specified")
        return
    end
    if not fs.exists(self.file) then
        fs.open(self.file, "w")
        fs.write(textutils.serialiseJSON({data = {}}))
        fs.close()
    end

    local file = fs.open(self.file, "r")
    self.data = self:DeserializeData(textutils.unserialiseJSON(file.readAll()).data)
    file:close()
end

--- OVERRIDE
function JsonDB:SerializeData()
    return self.data
end

--- OVERRIDE
function JsonDB:DeserializeData(data)
    return data
end

function JsonDB:Persist()
    if not self.file then
        error("JsonDB: No file specified")
        return
    end

    local file = fs.open(self.file, "w")
    file.write(textutils.serialiseJSON({data = self:SerializeData()}))
    file.close()
end

return JsonDB
