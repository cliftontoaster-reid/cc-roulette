--[[
    ToasterGen Spin

    Copyright (C) 2025 Clifton Toaster Reid <cliftontreid@duck.com>

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with this library. If not, see <https://www.gnu.org/licenses/>.
]]

---@class Logger
---@field LEVELS table<string, {priority: number, color: number}>
---@field getTimestamp fun(): string
---@field debug fun(message: string): nil
---@field info fun(message: string): nil
---@field warning fun(message: string): nil
---@field error fun(message: string): nil
---@field success fun(message: string): nil

local Logger = {
	LEVELS = {
		DEBUG = { priority = 1, color = colors.gray },
		INFO = { priority = 2, color = colors.lightGray },
		WARNING = { priority = 3, color = colors.yellow },
		ERROR = { priority = 4, color = colors.red },
		SUCCESS = { priority = 2, color = colors.lime },
	},
}

function Logger.getTimestamp()
	return os.date("[%Y-%m-%d %H:%M:%S]")
end

--- Log a message to the console as DEBUG
--- @param ... any, arguments for message formatting.
function Logger.debug(...)
	local msg = string.format(...)
	if msg then
		Logger.log("DEBUG", msg)
	end
end

--- Log a message to the console as INFO
--- @param ... any, arguments for message formatting.
function Logger.info(...)
	local msg = string.format(...)
	if msg then
		Logger.log("INFO", msg)
	end
end

--- Log a message to the console as WARNING
--- @param ... any, arguments for message formatting.
function Logger.warning(...)
	local msg = string.format(...)
	if msg then
		Logger.log("WARNING", msg)
	end
end

--- Log a message to the console as ERROR
--- @param ... any, arguments for message formatting.
function Logger.error(...)
	local msg = string.format(...)
	if msg then
		Logger.log("ERROR", msg)
	end
end

--- Log a message to the console as SUCCESS
--- @param ... any, arguments for message formatting.
function Logger.success(...)
	local msg = string.format(...)
	if msg then
		Logger.log("SUCCESS", msg)
	end
end

-- Update the main log function to align output
function Logger.log(level, message)
	local trimmedLevel = level:gsub("%s+$", "")
	local logConfig = Logger.LEVELS[trimmedLevel]
	local currentLevel = Logger.LEVELS[CONFIG.LOG_LEVEL].priority

	if logConfig.priority >= currentLevel then
		local oldColour = term.getTextColour()

		-- Use colour only if supported
		if term.isColor() then
			term.setTextColour(logConfig.color)
		end

		-- Format with fixed width for level to ensure alignment
		local timestamp = Logger.getTimestamp()
		local levelPadded = string.format("%-8s", "[" .. level .. "]")
		local logMessage = timestamp .. " " .. levelPadded .. " " .. message

		print(logMessage)

		-- Write to log file if enabled
		if CONFIG.LOG_FILE then
			local file = fs.open(CONFIG.LOG_FILE, fs.exists(CONFIG.LOG_FILE) and "a" or "w")
			if file then
				file.writeLine(logMessage)
				file.close()
			end
		end

		term.setTextColour(oldColour)
	end
end

return Logger
