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
        SUCCESS = { priority = 2, color = colors.lime }
    }
}

function Logger.getTimestamp()
    return os.date("[%Y-%m-%d %H:%M:%S]")
end

--- Log a message to the console as DEBUG
--- @param ... any, arguments for message formatting.
function Logger.debug(...)
    Logger.log("DEBUG  ", string.format(...))
end

--- Log a message to the console as INFO
--- @param ... any, arguments for message formatting.
function Logger.info(...)
    Logger.log("INFO   ", string.format(...))
end

--- Log a message to the console as WARNING
--- @param ... any, arguments for message formatting.
function Logger.warning(...)
    Logger.log("WARNING", string.format(...))
end

--- Log a message to the console as ERROR
--- @param ... any, arguments for message formatting.
function Logger.error(...)
    Logger.log("ERROR  ", string.format(...))
end

--- Log a message to the console as SUCCESS
--- @param ... any, arguments for message formatting.
function Logger.success(...)
    Logger.log("SUCCESS", string.format(...))
end

return Logger
