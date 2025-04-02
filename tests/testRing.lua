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

local package_path = package.path

-- Construct the new path using a relative path
local src_path = "./../?.lua;"

-- Prepend the 'src' path
package.path = src_path .. package_path
print(package.path)

local ring = require("src.ring")
ring.init("left")

-- Default values
local min = 100
local max = 200

-- Check for command line arguments
if arg and #arg >= 2 then
    local newMin = tonumber(arg[1])
    local newMax = tonumber(arg[2])

    if newMin and newMax and newMin < newMax then
        min = newMin
        max = newMax
    else
        print("Invalid arguments. Using default values (" .. min .. "-" .. max .. ")")
    end
end

while true do
    ring.launchBall(math.random(min, max))
    os.sleep(2)
end
