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

--- Log a message to the console with a specific level
--- @param level string The log level (DEBUG, INFO, WARNING, ERROR, SUCCESS)
--- @param ... any, arguments for message formatting.
function Logger.log(level, ...)
	local msg = string.format(...)
	if msg then
		local logLevel = Logger.LEVELS[level]
		if logLevel then
			term.setTextColor(logLevel.color)
			print(string.format("%s %s: %s", Logger.getTimestamp(), level, msg))
			term.setTextColor(colors.white)
		else
			error("Invalid log level: " .. level)
		end
	end
end

return Logger
