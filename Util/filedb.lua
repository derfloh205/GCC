local Object = require("GCC/Util/classics")

---@class FileDB.Options
---@field file string

---@class FileDB : Object
---@field file string
---@field data table
---@overload fun(options: FileDB.Options):FileDB
local FileDB = Object:extend()

function FileDB:new(options)
    options = options or {}
    self.file = options.file
    self.data = {}
    self:Load()
end

function FileDB:Load()
    if not self.file then
        error("FileDB: No file specified")
        return
    end
    if not fs.exists(self.file) then
        local file = fs.open(self.file, "w")
        file.write(textutils.serialise({data = {}}))
        file.close()
    end

    local file = fs.open(self.file, "r")
    self.data = self:DeserializeData(textutils.unserialise(file.readAll()).data)
    file:close()
end

--- OVERRIDE
function FileDB:SerializeData()
    return self.data
end

--- OVERRIDE
function FileDB:DeserializeData(data)
    return data
end

function FileDB:Persist()
    if not self.file then
        error("FileDB: No file specified")
        return
    end

    local file = fs.open(self.file, "w")
    file.write(textutils.serialise({data = self:SerializeData()}))
    file.close()
end

return FileDB
