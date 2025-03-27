--[[
    ToasterGen Spin

    Copyright (C) 2025 Clifton Toaster Reid <cliftontreid@duck.com>

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
]]

---@class Entry
--- Represents a database entry with metadata
---@field id number Unique numeric identifier of the entry
---@field data any User-provided data payload (must be JSON-serializable)
---@field createdAt number UNIX timestamp of creation
---@field updatedAt number UNIX timestamp of last modification

---@class Database
local Database = {}

--- Initializes and ensures the existence of the database directory structure.
---@param directory? string Custom root directory path (default: "/.db/")
---@return string Path to initialized directory
function Database.init(directory)
    directory = directory or "/.db/"
    if not fs.exists(directory) then
        fs.makeDir(directory)
    end
    return directory
end

--- Creates a new database entry in the specified collection.
---@param collection string Name of the collection (subdirectory)
---@param id number|string Numeric identifier for the record (auto-converted to number)
---@param data any Data payload to store (must be JSON-serializable)
---@return boolean success Operation status
---@return string? error_message Description of failure
function Database.create(collection, id, data)
    local directory = Database.init() .. collection .. "/"
    if not fs.exists(directory) then
        fs.makeDir(directory)
    end

    local path = directory .. id .. ".json"
    local file = fs.open(path, "w")
    if not file then
        return false, "Failed to open file for writing"
    end

    -- Create Entry with metadata
    local currentTime = os.time()
    local entry = {
        id = tonumber(id),
        data = data,
        createdAt = currentTime,
        updatedAt = currentTime
    }

    file.write(textutils.serializeJSON(entry))
    file.close()
    return true
end

--- Retrieves an entry from the specified collection.
---@param collection string Name of the collection (subdirectory)
---@param id number|string Numeric identifier of the record
---@return Entry? entry Deserialized entry object if found
---@return string? error_message Description of failure
function Database.read(collection, id)
    local directory = Database.init() .. collection .. "/"
    if not fs.exists(directory) then
        return nil, "Collection does not exist"
    end

    local path = directory .. id .. ".json"
    if not fs.exists(path) then
        return nil, "Record does not exist"
    end

    local file = fs.open(path, "r")
    if not file then
        return nil, "Failed to open file for reading"
    end

    local content = file.readAll()
    file.close()

    -- Return the complete Entry object
    return textutils.unserializeJSON(content)
end

--- Updates an existing entry's data while preserving metadata.
---@param collection string Name of the collection (subdirectory)
---@param id number|string Numeric identifier of the record
---@param data any New data payload to store (must be JSON-serializable)
---@return boolean success Operation status
---@return string? error_message Description of failure
function Database.update(collection, id, data)
    local directory = Database.init() .. collection .. "/"
    if not fs.exists(directory) then
        return false, "Collection does not exist"
    end

    local path = directory .. id .. ".json"
    if not fs.exists(path) then
        return false, "Record does not exist"
    end

    -- Read existing entry
    local file = fs.open(path, "r")
    if not file then
        return false, "Failed to open file for reading"
    end

    local content = file.readAll()
    file.close()

    local entry = textutils.unserializeJSON(content)

    -- Update entry
    entry.data = data
    entry.updatedAt = os.time()

    -- Write updated entry
    file = fs.open(path, "w")
    if not file then
        return false, "Failed to open file for writing"
    end

    file.write(textutils.serializeJSON(entry))
    file.close()
    return true
end

--- Permanently deletes an entry from the database.
---@param collection string Name of the collection (subdirectory)
---@param id number|string Numeric identifier of the record
---@return boolean success Operation status (true even if file didn't exist)
---@return string? error_message Description of failure
function Database.delete(collection, id)
    local directory = Database.init() .. collection .. "/"
    if not fs.exists(directory) then
        return false, "Collection does not exist"
    end

    local path = directory .. id .. ".json"
    if not fs.exists(path) then
        return false, "Record does not exist"
    end

    return fs.delete(path)
end

--- Lists all record IDs in a collection.
---@param collection string Name of the collection (subdirectory)
---@return string[] Array of record IDs as strings
function Database.list(collection)
    local directory = Database.init() .. collection .. "/"
    if not fs.exists(directory) then
        return {}
    end

    local files = fs.list(directory)
    local records = {}

    for _, file in ipairs(files) do
        if string.match(file, "%.json$") then
            local id = string.sub(file, 1, -6) -- Remove .json extension
            table.insert(records, id)
        end
    end

    return records
end

--- Checks if an entry exists in the specified collection.
---@param collection string Name of the collection (subdirectory)
---@param id number|string Numeric identifier of the record
---@return boolean exists True if the entry exists, false otherwise
function Database.exists(collection, id)
    local directory = Database.init() .. collection .. "/"
    if not fs.exists(directory) then
        return false
    end

    local path = directory .. id .. ".json"
    return fs.exists(path)
end

--- Retrieves nested values from objects using dot-notation paths
---@param obj table Root table to search
---@param path string Dot-separated path (e.g., "user.profile.age")
---@return any|nil value Found value or nil if path invalid
local function getNestedValue(obj, path)
    local current = obj
    for segment in string.gmatch(path, "[^%.]+") do
        if type(current) ~= "table" or current[segment] == nil then
            return nil
        end
        current = current[segment]
    end
    return current
end

--- Searches for entries matching query criteria in the collection.
---@param collection string Name of the collection (subdirectory)
---@param query table Key-value pairs to match against entry.data.
---                   Supports dot notation for nested fields (e.g., {["user.name"] = "John"})
---@return Entry[] results Array of matching Entry objects
---@return string? error_message Description of failure
function Database.search(collection, query)
    local directory = Database.init() .. collection .. "/"
    if not fs.exists(directory) then
        return {}, "Collection does not exist"
    end

    local files = fs.list(directory)
    local results = {}

    for _, file in ipairs(files) do
        if string.match(file, "%.json$") then
            local path = directory .. file
            local fileHandle = fs.open(path, "r")
            if fileHandle then
                local content = fileHandle.readAll()
                fileHandle.close()

                local entry = textutils.unserializeJSON(content)
                local match = true

                for key, value in pairs(query) do
                    if getNestedValue(entry.data, key) ~= value then
                        match = false
                        break
                    end
                end

                if match then
                    table.insert(results, entry)
                end
            end
        end
    end

    return results
end

--- Checks if any entries matching the query criteria exist in the specified collection.
---@param collection string Name of the collection (subdirectory)
---@param query table Key-value pairs to match against entry.data
---@return boolean exists True if at least one matching entry exists
---@return string? error_message Description of failure
function Database.existsQuery(collection, query)
    local results, err = Database.search(collection, query)
    if err then
        return false, err
    end
    return #results > 0
end

return Database
