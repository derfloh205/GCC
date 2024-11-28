local baseUrl = "https://raw.githubusercontent.com/derfloh205/GTurtle/refs/heads/main/"
local files = {
    "classics", "gitpull", "gnav", "init", "pull", "table_utils", "vector_utils"
}

for _, f in ipairs(files) do
    local fileName = f .. ".lua"
    local url = baseUrl .. fileName
    local response = http.get(url)
    if response then
        print("Pulling " .. fileName .. " ..")
        if fs.exists(fileName) then
            fs.delete(fileName)
        end
        local fileContent = response.readAll()
        local file = fs.open(fileName, "w")
        file.write(fileContent)
        file.close()
    else
        print("Failed to Pull: " .. fileName)
    end
end