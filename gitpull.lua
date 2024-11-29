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

-- for _, f in ipairs(files) do
--     local fileName = f .. ".lua"
--     local url = baseUrl .. fileName
--     shell.run("rm", fileName)
--     shell.run("wget", url, fileName)
-- end

for _, f in ipairs(files) do
    local fileName = f .. ".lua"
    local url = baseUrl .. fileName
    local response = http.get(url, {["Cache-Control"] = "no-cache"})
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
