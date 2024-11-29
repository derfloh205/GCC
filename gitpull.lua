local baseUrl = "https://github.com/derfloh205/GTurtle/raw/refs/heads/main/"
local baseDir = shell.dir()
local files = {
    "classics",
    "gitpull",
    "gnav",
    "init",
    "tutils",
    "vutils"
}

-- tag test: h

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
