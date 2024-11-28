local baseUrl = "https://raw.githubusercontent.com/derfloh205/GTurtle/refs/heads/main/"
local files = {
    "ckassics", "gitpull", "gnav", "init", "pull", "table_utils", "vector_utils"
}

for _, f in files do
    local fileName = f .. ".lua"
    local url = baseUrl .. fileName
    local response = http.get(url)
    local fileContent = response.readAll()
    local file = fs.open(fileName, "w")
    file.write(fileContent)
    file.close()
end