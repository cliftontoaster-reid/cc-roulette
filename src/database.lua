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
local Tracer = require("src.trace")

--- Initializes and ensures the existence of the database directory structure.
---@param directory? string Custom root directory path (default: "/.db/")
---@return string Path to initialized directory
function Database.init(directory)
	local tr = Tracer.new()
	tr:setName("database.init")
	tr:addTag("directory", directory or "/.db/")

	directory = directory or "/.db/"
	if not fs.exists(directory) then
		tr:addAnnotation("Directory does not exist, creating.")
		fs.makeDir(directory)
	else
		tr:addAnnotation("Directory already exists.")
	end

	Tracer.addSpan(tr:endSpan())
	return directory
end

--- Creates a new database entry in the specified collection.
---@param collection string Name of the collection (subdirectory)
---@param id number|string Numeric identifier for the record (auto-converted to number)
---@param data any Data payload to store (must be JSON-serializable)
---@return boolean success Operation status
---@return string? error_message Description of failure
function Database.create(collection, id, data)
	local tr = Tracer.new()
	tr:setName("database.create")
	tr:addTag("collection", collection)
	tr:addTag("id", tostring(id))

	local directory = Database.init(nil) .. collection .. "/"
	if not fs.exists(directory) then
		tr:addAnnotation("Collection directory does not exist, creating.")
		fs.makeDir(directory)
	end

	local path = directory .. id .. ".json"
	tr:addTag("path", path)

	local file, err = fs.open(path, "w")
	if not file then
		tr:addAnnotation("Failed to open file for writing: " .. (err or "unknown error"))
		Tracer.addSpan(tr:endSpan())
		return false, "Failed to open file for writing"
	end

	-- Create Entry with metadata
	local currentTime = os.time()
	local entry = {
		id = tonumber(id),
		data = data,
		createdAt = currentTime,
		updatedAt = currentTime,
	}

	local success, writeErr = pcall(function() file.write(textutils.serializeJSON(entry)) end)
	file.close()

	if not success then
		tr:addAnnotation("Failed to write JSON data: " .. (writeErr or "unknown error"))
		Tracer.addSpan(tr:endSpan())
		pcall(function() fs.delete(path) end)
		return false, "Failed to write data"
	end

	tr:addAnnotation("Entry created successfully.")
	Tracer.addSpan(tr:endSpan())
	return true
end

--- Retrieves an entry from the specified collection.
---@param collection string Name of the collection (subdirectory)
---@param id number|string Numeric identifier of the record
---@return Entry? entry Deserialized entry object if found
---@return string? error_message Description of failure
function Database.read(collection, id)
	local tr = Tracer.new()
	tr:setName("database.read")
	tr:addTag("collection", collection)
	tr:addTag("id", tostring(id))

	local directory = Database.init(nil) .. collection .. "/"
	if not fs.exists(directory) then
		tr:addAnnotation("Collection does not exist.")
		Tracer.addSpan(tr:endSpan())
		return nil, "Collection does not exist"
	end

	local path = directory .. id .. ".json"
	tr:addTag("path", path)
	if not fs.exists(path) then
		tr:addAnnotation("Record does not exist.")
		Tracer.addSpan(tr:endSpan())
		return nil, "Record does not exist"
	end

	local file, err = fs.open(path, "r")
	if not file then
		tr:addAnnotation("Failed to open file for reading: " .. (err or "unknown error"))
		Tracer.addSpan(tr:endSpan())
		return nil, "Failed to open file for reading"
	end

	local content = file.readAll()
	file.close()

	local success, entry = pcall(function() return textutils.unserializeJSON(content) end)

	if not success then
		tr:addAnnotation("Failed to unserialize JSON content.")
		Tracer.addSpan(tr:endSpan())
		return nil, "Failed to parse record data"
	end

	tr:addAnnotation("Entry read successfully.")
	Tracer.addSpan(tr:endSpan())
	return entry
end

--- Updates an existing entry's data while preserving metadata.
---@param collection string Name of the collection (subdirectory)
---@param id number|string Numeric identifier of the record
---@param data any New data payload to store (must be JSON-serializable)
---@return boolean success Operation status
---@return string? error_message Description of failure
function Database.update(collection, id, data)
	local tr = Tracer.new()
	tr:setName("database.update")
	tr:addTag("collection", collection)
	tr:addTag("id", tostring(id))

	local directory = Database.init(nil) .. collection .. "/"
	if not fs.exists(directory) then
		tr:addAnnotation("Collection does not exist.")
		Tracer.addSpan(tr:endSpan())
		return false, "Collection does not exist"
	end

	local path = directory .. id .. ".json"
	tr:addTag("path", path)
	if not fs.exists(path) then
		tr:addAnnotation("Record does not exist.")
		Tracer.addSpan(tr:endSpan())
		return false, "Record does not exist"
	end

	local existingEntry, readErr = Database.read(collection, id)
	if not existingEntry then
		tr:addAnnotation("Failed to read existing entry for update: " .. (readErr or "unknown error"))
		Tracer.addSpan(tr:endSpan())
		return false, "Failed to read existing record for update"
	end

	existingEntry.data = data
	existingEntry.updatedAt = os.time()

	local file, openErr = fs.open(path, "w")
	if not file then
		tr:addAnnotation("Failed to open file for writing update: " .. (openErr or "unknown error"))
		Tracer.addSpan(tr:endSpan())
		return false, "Failed to open file for writing"
	end

	local success, writeErr = pcall(function() file.write(textutils.serializeJSON(existingEntry)) end)
	file.close()

	if not success then
		tr:addAnnotation("Failed to write updated JSON data: " .. (writeErr or "unknown error"))
		Tracer.addSpan(tr:endSpan())
		return false, "Failed to write updated data"
	end

	tr:addAnnotation("Entry updated successfully.")
	Tracer.addSpan(tr:endSpan())
	return true
end

--- Permanently deletes an entry from the database.
---@param collection string Name of the collection (subdirectory)
---@param id number|string Numeric identifier of the record
---@return boolean success Operation status (true even if file didn't exist)
---@return string? error_message Description of failure
function Database.delete(collection, id)
	local tr = Tracer.new()
	tr:setName("database.delete")
	tr:addTag("collection", collection)
	tr:addTag("id", tostring(id))

	local directory = Database.init(nil) .. collection .. "/"
	if not fs.exists(directory) then
		tr:addAnnotation("Collection does not exist.")
		Tracer.addSpan(tr:endSpan())
		return false, "Collection does not exist"
	end

	local path = directory .. id .. ".json"
	tr:addTag("path", path)
	if not fs.exists(path) then
		tr:addAnnotation("Record does not exist, nothing to delete.")
		Tracer.addSpan(tr:endSpan())
		return false, "Record does not exist"
	end

	local success, err = pcall(function() return fs.delete(path) end)

	if not success then
		tr:addAnnotation("Failed to delete file: " .. (err or "unknown error"))
		Tracer.addSpan(tr:endSpan())
		return false, "Failed to delete record"
	end

	tr:addAnnotation("Entry deleted successfully.")
	Tracer.addSpan(tr:endSpan())
	return true
end

--- Lists all record IDs in a collection.
---@param collection string Name of the collection (subdirectory)
---@return string[] Array of record IDs as strings
function Database.list(collection)
	local tr = Tracer.new()
	tr:setName("database.list")
	tr:addTag("collection", collection)

	local directory = Database.init(nil) .. collection .. "/"
	if not fs.exists(directory) then
		tr:addAnnotation("Collection does not exist.")
		Tracer.addSpan(tr:endSpan())
		return {}
	end

	local files = fs.list(directory)
	local records = {}

	for _, file in ipairs(files) do
		if string.match(file, "%.json$") then
			local id = string.sub(file, 1, -6)
			table.insert(records, id)
		end
	end

	tr:addAnnotation(string.format("Found %d records.", #records))
	Tracer.addSpan(tr:endSpan())
	return records
end

--- Checks if an entry exists in the specified collection.
---@param collection string Name of the collection (subdirectory)
---@param id number|string Numeric identifier of the record
---@return boolean exists True if the entry exists, false otherwise
function Database.exists(collection, id)
	local tr = Tracer.new()
	tr:setName("database.exists")
	tr:addTag("collection", collection)
	tr:addTag("id", tostring(id))

	local directory = Database.init(nil) .. collection .. "/"
	if not fs.exists(directory) then
		tr:addAnnotation("Collection does not exist.")
		Tracer.addSpan(tr:endSpan())
		return false
	end

	local path = directory .. id .. ".json"
	tr:addTag("path", path)
	local exists = fs.exists(path)
	tr:addAnnotation(exists and "Record exists." or "Record does not exist.")
	Tracer.addSpan(tr:endSpan())
	return exists
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
	local tr = Tracer.new()
	tr:setName("database.search")
	tr:addTag("collection", collection)

	local directory = Database.init(nil) .. collection .. "/"
	if not fs.exists(directory) then
		tr:addAnnotation("Collection does not exist.")
		Tracer.addSpan(tr:endSpan())
		return {}, "Collection does not exist"
	end

	local files = fs.list(directory)
	local results = {}
	local filesChecked = 0
	local filesMatched = 0

	for _, file in ipairs(files) do
		if string.match(file, "%.json$") then
			filesChecked = filesChecked + 1
			local path = directory .. file
			local fileHandle, openErr = fs.open(path, "r")
			if fileHandle then
				local content = fileHandle.readAll()
				fileHandle.close()

				local success, entry = pcall(function() return textutils.unserializeJSON(content) end)
				if success and entry and type(entry.data) == "table" then
					local match = true
					for key, value in pairs(query) do
						if getNestedValue(entry.data, key) ~= value then
							match = false
							break
						end
					end

					if match then
						filesMatched = filesMatched + 1
						table.insert(results, entry)
					end
				elseif not success then
					tr:addAnnotation(string.format("Failed to parse file %s during search.", file))
				end
			else
				tr:addAnnotation(string.format("Failed to open file %s for reading during search: %s", file,
					openErr or "unknown"))
			end
		end
	end

	tr:addAnnotation(string.format("Search complete. Checked %d files, found %d matches.", filesChecked, filesMatched))
	Tracer.addSpan(tr:endSpan())
	return results
end

--- Checks if any entries matching the query criteria exist in the specified collection.
---@param collection string Name of the collection (subdirectory)
---@param query table Key-value pairs to match against entry.data
---@return boolean exists True if at least one matching entry exists
---@return string? error_message Description of failure
function Database.existsQuery(collection, query)
	local tr = Tracer.new()
	tr:setName("database.existsQuery")
	tr:addTag("collection", collection)

	local directory = Database.init(nil) .. collection .. "/"
	if not fs.exists(directory) then
		tr:addAnnotation("Collection does not exist.")
		Tracer.addSpan(tr:endSpan())
		return false, "Collection does not exist"
	end

	local files = fs.list(directory)
	local foundMatch = false

	for _, file in ipairs(files) do
		if string.match(file, "%.json$") then
			tr:addAnnotation(string.format("Checking file: %s", file))
			local path = directory .. file
			local fileHandle, openErr = fs.open(path, "r")
			if fileHandle then
				tr:addAnnotation(string.format("Successfully opened %s for reading.", file))
				local content = fileHandle.readAll()
				fileHandle.close()

				local success, entry = pcall(function() return textutils.unserializeJSON(content) end)
				if success and entry and type(entry.data) == "table" then
					tr:addAnnotation(string.format("Successfully parsed %s.", file))
					local match = true
					for key, value in pairs(query) do
						tr:addAnnotation(string.format("Checking query key '%s' against data in %s.", key, file))
						if getNestedValue(entry.data, key) ~= value then
							tr:addAnnotation(string.format("Query mismatch for key '%s' in %s.", key, file))
							match = false
							break
						end
					end

					if match then
						tr:addAnnotation(string.format("Found matching entry in file %s. Stopping search.", file))
						foundMatch = true
						break -- Exit the loop as soon as a match is found
					end
				elseif not success then
					tr:addAnnotation(string.format("Failed to parse file %s during existsQuery.", file))
				else
					tr:addAnnotation(string.format("Parsed file %s, but entry.data is not a table.", file))
				end
			else
				tr:addAnnotation(string.format("Failed to open file %s for reading during existsQuery: %s", file,
					openErr or "unknown"))
			end
		else
			tr:addAnnotation(string.format("Skipping non-JSON file: %s", file))
		end
	end

	tr:addAnnotation(foundMatch and "Matching entry found." or "No matching entry found.")
	Tracer.addSpan(tr:endSpan())
	return foundMatch
end

return Database
