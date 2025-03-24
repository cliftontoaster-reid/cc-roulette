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

function Logger.debug(message)
    Logger.log("DEBUG  ", message)
end

function Logger.info(message)
    Logger.log("INFO   ", message)
end

function Logger.warning(message)
    Logger.log("WARNING", message)
end

function Logger.error(message)
    Logger.log("ERROR  ", message)
end

function Logger.success(message)
    Logger.log("SUCCESS", message)
end

return Logger
