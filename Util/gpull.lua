---@class GCC.Util.GPull
local GPull = {}

local args = {...}

if #args < 3 then
    print("Usage: gpull <user> <repo> <access-token>")
    return
end

local user = args[1]
local repo = args[2]
local token = args[3]

local headers = {
    ["Accept"] = "application/vnd.github+json",
    ["Authorization"] = string.format("Bearer %s", token),
    ["X-GitHub-Api-Version"] = "2022-11-28"
}

function GPull:Get(url)
    -- TODO: Use Token for auth
    return http.get(url, headers)
end

function GPull:UpdateBlob(commitSha, path, fileName)
    print("Pulling " .. fileName .. " ..")
    local fileUrl =
        string.format("https://raw.githubusercontent.com/%s/%s/%s/%s/%s", user, repo, commitSha, path, fileName)
    local response = self:Get(fileUrl)
    if response then
        local basePath = fs.combine(repo, path)
        fs.makeDir(basePath)
        local filePath = fs.combine(basePath, fileName)
        local fileContent = response.readAll()
        local file = fs.open(filePath, "w")
        file.write(fileContent)
        file.close()
    else
        print("Failed to Pull: " .. fileUrl)
    end
end

function GPull:UpdateTree(commitSha, path, treeData)
    local sha = treeData.sha
    -- compare to cache, only update if different
    local url = treeData.url
    local treeResponse = self:Get(url)
    local treeJson = textutils.unserialiseJSON(treeResponse.readAll())
    local subTreeList = treeJson.tree

    for _, subTreeData in ipairs(subTreeList) do
        if subTreeData.type == "tree" then
            self:UpdateTree(commitSha, fs.combine(path, subTreeData.path), subTreeData)
        elseif subTreeData.type == "blob" then
            self:UpdateBlob(commitSha, path, subTreeData.path)
        end
    end
end

function GPull:PullRepository()
    print(string.format("Pulling from github.com/%s/%s", user, repo))
    local commitApiUrl = string.format("https://api.github.com/repos/%s/%s/commits", user, repo)
    local commitResponse = self:Get(commitApiUrl)
    local commitResponseJSON = textutils.unserialiseJSON(commitResponse.readAll())
    local commitSha = commitResponseJSON[1].sha

    self:UpdateTree(commitSha, "", commitResponseJSON[1].commit.tree)
end

GPull:PullRepository()
