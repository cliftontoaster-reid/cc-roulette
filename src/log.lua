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
---@field LEVELS table<string, { priority: number, color: number }> Log levels with priority and color.
---@field cachedRequest LokiRequest The current batch of logs waiting to be sent.
---@field setLokiURL fun(url: string) Sets the URL for the Loki logging endpoint.
---@field getLokiURL fun(): string|nil Gets the currently configured Loki URL.
---@field sendLogs fun() Sends the cached log entries to the configured Loki endpoint.
---@field getTimestamp fun(): string Returns the current timestamp formatted as [YYYY-MM-DD HH:MM:SS].
---@field debug fun(fmt: string, ...) Logs a message with DEBUG level.
---@field info fun(fmt: string, ...) Logs a message with INFO level.
---@field warning fun(fmt: string, ...) Logs a message with WARNING level.
---@field error fun(fmt: string, ...) Logs a message with ERROR level.
---@field success fun(fmt: string, ...) Logs a message with SUCCESS level.
---@field getLogLevel fun(): string Gets the current minimum log level.
---@field setLogLevel fun(level: string) Sets the minimum log level.
---@field log fun(level: string, ...) Logs a message with the specified level.

---@class LokiRequest
---@field streams LokiStream[]
---@field streamMap table<string, number>

---@class LokiStream
---@field stream table<string, string>
---@field values { [0]: string, [1]: string, [2]: LokiExtra | nil }[]

---@class LokiExtra
---@field trace_id string | nil
---@field user_id string | nil

---@type string | nil
local LOKI_URL = nil              -- Loki URL for sending logs
---@type string
local CURRENT_LOG_LEVEL = "DEBUG" -- Default level, shows all logs

local expect = require("cc.expect").expect

local Logger

local function newRequest()
	return {
		streams = {},
		streamMap = {}
	}
end

local function newLokiEntry(msg, extra)
	local entry = {
		[0] = os.epoch() * 1e6, -- convert ms to ns
		[1] = msg,
	}
	if extra then
		entry[2] = extra
	end
	return entry
end

-- helper to batch log entries into streams by labels (including level)
local function addToCache(level, msg, extra)
	-- Construct a table of labels for this log entry.
	-- 'job' is the computer label (or "unknown" if not set),
	-- 'host' is the computer ID, and 'level' is the log level.
	local labels = { job = os.getComputerLabel() or "unknown", host = os.getComputerID(), level = level }

	-- Build a stable, unique key for this label set by concatenating sorted key-value pairs.
	local parts = {}
	for k, v in pairs(labels) do
		parts[#parts + 1] = k .. "=" .. v
	end
	table.sort(parts) -- Ensure consistent order for the key.
	local key = table.concat(parts, ",")

	-- Check if a stream for this label set already exists in the cache.
	local idx = Logger.cachedRequest.streamMap[key]
	if not idx then
		-- If not, create a new stream entry and update the stream map.
		idx = #Logger.cachedRequest.streams + 1
		Logger.cachedRequest.streams[idx] = { stream = labels, values = {} }
		Logger.cachedRequest.streamMap[key] = idx
	end

	-- Add the new log entry (with optional extra fields) to the appropriate stream.
	table.insert(Logger.cachedRequest.streams[idx].values, newLokiEntry(msg, extra))
end

-- retry HTTP POST with exponential backoff
local function postWithRetry(url, body, headers)
	local maxRetries, backoff = 3, 1
	for i = 1, maxRetries do
		local ok, resp = pcall(http.post, url, body, headers)
		if ok and resp then return resp end
		sleep(backoff)
		backoff = backoff * 2
	end
	return nil
end

Logger = {
	LEVELS = {
		DEBUG = { priority = 1, color = colors.gray },
		INFO = { priority = 2, color = colors.lightGray },
		WARNING = { priority = 3, color = colors.yellow },
		ERROR = { priority = 4, color = colors.red },
		SUCCESS = { priority = 2, color = colors.lime },
	},
	cachedRequest = newRequest(),
}

function Logger.setLokiURL(url)
	expect(1, url, "string")
	local valid, reason = http.checkURL(url)
	if not valid then
		Logger.error("The following URL (" .. url .. ") is invalid: " .. reason)
		error("Invalid URL: " .. reason)
		return
	end
	LOKI_URL = url
end

function Logger.getLokiURL()
	return LOKI_URL
end

function Logger.sendLogs()
	if LOKI_URL and #Logger.cachedRequest.streams > 0 then
		local request = Logger.cachedRequest
		local response = postWithRetry(LOKI_URL, textutils.serializeJSON(request), {
			["Content-Type"] = "application/json",
		})
		if response then
			-- temporarily disable Loki push for status logs
			local prevURL = LOKI_URL
			LOKI_URL = nil
			if response.getResponseCode() == 204 then
				Logger.info("Logs sent to Loki successfully.")
			else
				Logger.error("Failed to send logs to Loki. Response code: " .. response.getResponseCode())
			end
			LOKI_URL = prevURL
		else
			-- temporarily disable Loki push for status logs
			local prevURL = LOKI_URL
			LOKI_URL = nil
			Logger.error("Failed to send logs to Loki.")
			LOKI_URL = prevURL
		end
		-- clear the cache so sent logs aren’t re-sent
		Logger.cachedRequest = newRequest()
	end

	-- Reset the cached request to avoid sending duplicate logs
	Logger.cachedRequest = newRequest()
end

--- Returns the current timestamp in the format [YYYY-MM-DD HH:MM:SS]
---@return string|osdate time
function Logger.getTimestamp()
	return os.date("[%Y-%m-%d %H:%M:%S]")
end

--- Log a message to the console as DEBUG
--- @param fmt string, format string for message.
--- @param ... any, arguments for message formatting.
function Logger.debug(fmt, ...)
	expect(1, fmt, "string")
	local msg = string.format(fmt, ...)
	if msg then
		Logger.log("DEBUG", msg)
	end
end

--- Log a message to the console as INFO
--- @param fmt string, format string for message.
--- @param ... any, arguments for message formatting.
function Logger.info(fmt, ...)
	expect(1, fmt, "string")
	local msg = string.format(fmt, ...)
	if msg then
		Logger.log("INFO", msg)
	end
end

--- Log a message to the console as WARNING
--- @param fmt string, format string for message.
--- @param ... any, arguments for message formatting.
function Logger.warning(fmt, ...)
	expect(1, fmt, "string")
	local msg = string.format(fmt, ...)
	if msg then
		Logger.log("WARNING", msg)
	end
end

--- Log a message to the console as ERROR
--- @param fmt string, format string for message.
--- @param ... any, arguments for message formatting.
function Logger.error(fmt, ...)
	expect(1, fmt, "string")
	local msg = string.format(fmt, ...)
	if msg then
		Logger.log("ERROR", msg)
	end
end

--- Log a message to the console as SUCCESS
--- @param fmt string, format string for message.
--- @param ... any, arguments for message formatting.
function Logger.success(fmt, ...)
	expect(1, fmt, "string")
	local msg = string.format(fmt, ...)
	if msg then
		Logger.log("SUCCESS", msg)
	end
end

--- Get the current log level
--- @return string The current log level
function Logger.getLogLevel()
	return CURRENT_LOG_LEVEL
end

--- Set the log level, logs below this level will be ignored
--- @param level string The log level (DEBUG, INFO, WARNING, ERROR, SUCCESS)
function Logger.setLogLevel(level)
	expect(1, level, "string")
	if not Logger.LEVELS[level] then
		error("Invalid log level: " .. level)
		return
	end
	CURRENT_LOG_LEVEL = level
end

local logFile = fs.open("/log.txt", "a")

--- Log a message to the console with a specific level
--- @param level string The log level (DEBUG, INFO, WARNING, ERROR, SUCCESS)
--- @param ... any, arguments for message formatting.
function Logger.log(level, ...)
	expect(1, level, "string")
	local msg = string.format(...)
	if msg then
		local logLevel = Logger.LEVELS[level]
		if logLevel then
			-- Check if this log level should be displayed
			local currentLevelInfo = Logger.LEVELS[CURRENT_LOG_LEVEL]
			if currentLevelInfo and logLevel.priority >= currentLevelInfo.priority then
				term.setTextColor(logLevel.color)
				print(string.format("%s %s: %s", Logger.getTimestamp(), level, msg))
				logFile.write(string.format("%s: %s\n", Logger.getTimestamp(), level, msg))
				if LOKI_URL then
					addToCache(level, msg)
				end
				logFile.flush()
				term.setTextColor(colors.white)
			end
		else
			error("Invalid log level: " .. level)
		end
	end
end

return Logger
