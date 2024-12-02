local commitApiUrl = "https://api.github.com/repos/derfloh205/GCC/commits"

local cResponse = http.get(commitApiUrl)
local commits = textutils.unserialiseJSON(cResponse.readAll())
local latestSha = commits[1].sha

local baseUrl = string.format("https://raw.githubusercontent.com/derfloh205/GCC/%s/", latestSha)
local baseDir = shell.dir()
local files = {
    "classics",
    "start_turtlehost",
    "gitpull",
    "gnav",
    "init",
    "tutils",
    "vutils",
    "testrun",
    "gnet"
}

for _, f in ipairs(files) do
    local fileName = f .. ".lua"
    local url = baseUrl .. fileName
    local response = http.get(url)
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
