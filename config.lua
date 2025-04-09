--[[
    ToasterGen Spin

    Copyright (C) 2025 Clifton Toaster Reid <cliftontreid@duck.com>

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
]]

local config = require("tools.config")

local dev = config.askOption("What device would you like to configure?", { "Table", "Server" })
if dev == "Table" then
	config.configTable()
elseif dev == "Server" then
	error("Server configuration not yet implemented, we apologize for the inconvenience")
end
