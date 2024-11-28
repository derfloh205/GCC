local table_utils = {}

function table_utils:tContains(table, i)
    for _, value in ipairs(table) do
        if value == i then
            return true
        end
    end
    return false
end

return table_utils