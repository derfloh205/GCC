local args = {...}

local url = args[2]
local file = string.gsub(args[1], ".lua", "") .. ".lua"
local id = string.gsub(url, "https://pastebin.com/", "")

shell.run("rm", file)
shell.run("pastebin", "get", id, file)