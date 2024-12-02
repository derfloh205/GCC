---@class GCC.Util.GPull
local GPull = {}

function GPull:UpdateBlob(commitSha, user, repo, path, blob)
    local fileName = string.format("%s.lua", blob)
    local fileUrl =
        string.format("https://raw.githubusercontent.com/%s/%s/%s/%s/%s", user, repo, commitSha, path, fileName)
    local response = http.get(fileUrl)
    if response then
        print("Pulling " .. fileName .. " ..")
        local filePath = fs.combine(path, fileName)
        -- if fs.exists(filePath) then
        --     fs.delete(filePath)
        -- end
        local fileContent = response.readAll()
        local file = fs.open(filePath, "w")
        file.write(fileContent)
        file.close()
    else
        print("Failed to Pull: " .. fileUrl)
    end
end

function GPull:UpdateTree(commitSha, user, repo, path, treeData)
    local sha = treeData.sha
    -- compare to cache, only update if different

    for _, subTreeData in ipairs(treeData.tree) do
        if subTreeData.type == "tree" then
            self:UpdateTree(commitSha, user, repo, fs.combine(path, subTreeData.path), subTreeData)
        elseif subTreeData.type == "blob" then
            self:UpdateBlob(commitSha, user, repo, path, subTreeData.path, subTreeData.url)
        end
    end
end

function GPull:PullRepository(user, repo)
    print(string.format("Pulling from github.com/%s/%s", user, repo))
    local commitApiUrl = string.format("https://api.github.com/repos/%s/%s/commits", user, repo)
    local commitResponse = http.get(commitApiUrl)
    local commitResponseJSON = textutils.unserialiseJSON(commitResponse.readAll())
    local commitSha = commitResponseJSON[1].sha
    -- use latest commit sha to check for newer commit
    local latestTreeUrl = commitResponseJSON[1].commit.tree.url
    local latestTreeResponse = http.get(latestTreeUrl)
    local latestTreeResponseJSON = textutils.unserialiseJSON(latestTreeResponse.readAll())

    self:UpdateTree(commitSha, user, repo, repo, latestTreeResponseJSON)
end

local args = {...}

if #args < 2 then
    print("Usage: gpull user repo")
    return
end

GPull:PullRepository(args[1], args[2])
