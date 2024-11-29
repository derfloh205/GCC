local args = {...}
if #args == 0 then
    print("Requires commit hash as first argument")
    return
end
-- TEST?!?!?!
local lastCommit = args[1]
local baseUrl = string.format("https://raw.githubusercontent.com/derfloh205/GTurtle/%s/", lastCommit)
local baseDir = shell.dir()
local files = {
    "classics",
    "gitpull",
    "gnav",
    "init",
    "tutils",
    "vutils"
}

local headers = {
    ["Cache-Control"] = "no-cache"
}

for _, f in ipairs(files) do
    local fileName = f .. ".lua"
    local url = baseUrl .. fileName
    local response = http.get(url, headers)
    if response then
        print("Pulling " .. fileName .. " ..")
        local filePath = fs.combine(baseDir, fileName)
        if fs.exists(filePath) then
            fs.delete(filePath)
        end
        local fileContent = response.readAll()
        local file = fs.open(filePath, "w")
        file.write(fileContent)
        file.close()
    else
        print("Failed to Pull: " .. fileName)
    end
end
