local f = string.format
local args = {...}
local scriptsBasePath = "GCC/Run/scripts/"

if not (#args) == 1 then
    print("Usage: run <script>")
    return
end

local script = args[1]
local fileName = script .. ".lua"
-- update root then run

if not fs.exists(fs.combine(scriptsBasePath, fileName)) then
    print(f("Script %s does not exist", script))
    return
end

if fs.exists(fileName) then
    fs.delete(fileName)
end

fs.copy(fs.combine(scriptsBasePath, fileName), fileName)

shell.run("cd", "/")
shell.run(script)
