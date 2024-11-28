local baseUrl = "https://raw.githubusercontent.com/derfloh205/GTurtle/refs/heads/main/"
local baseDir = shell.dir()
local files = {
    "classics",
    "gitpull",
    "gnav",
    "init",
    "tutils",
    "vutils"
}

for _, f in ipairs(files) do
    local fileName = f .. ".lua"
    local url = baseUrl .. fileName
    local response = http.get(url)
    if response then
        print("Pulling " .. fileName .. " ..")
        local filePath = fs.combine(baseDir, fileName)
        local fileContent = response.readAll()
        local file = fs.open(filePath, "w")
        file.write(fileContent)
        file.close()
    else
        print("Failed to Pull: " .. fileName)
    end
end
