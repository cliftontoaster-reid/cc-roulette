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
local src_path = "./../src/?.lua;"

-- Prepend the 'src' path
package.path = src_path .. package_path
print(package.path)

local carpet = require("carpet")

-- Add more test bets
local bet2 = {
    amount = 50,
    color = 8, -- pink
    player = "alice",
    number = 7
}
carpet.bets[2] = bet2

local bet3 = {
    amount = 200,
    color = 1, -- orange
    player = "bob",
    number = 24
}
carpet.bets[3] = bet3

-- Add a bet on the same number as another bet
local bet4 = {
    amount = 75,
    color = 4, -- yellow
    player = "dave",
    number = 3
}
carpet.bets[4] = bet4

-- Add a bet on zero
local bet5 = {
    amount = 150,
    color = 11, -- lightBlue
    player = "emma",
    number = 29
}
carpet.bets[5] = bet5


local bet6 = {
    amount = 100,
    color = 2, -- green
    player = "frank",
    number = 29
}
carpet.bets[6] = bet6

-- Add a bet on 52
local bet7 = {
    amount = 100,
    color = 2, -- green
    player = "frank",
    number = 52
}
carpet.bets[7] = bet7

carpet.update()

while true do
    local event = { os.pullEventRaw() }
    if event[1] == "monitor_touch" then
        print("Monitor touched at " .. event[3] .. "," .. event[4])

        local clickedNumber = carpet.findClickedNumber(event[3], event[4])
        if clickedNumber then
            print("Clicked number: " .. clickedNumber)
        else
            print("No valid number clicked.")
        end

        -- carpet.update()
    elseif event[1] == "terminate" then
        break
    end

    os.sleep(0.1)
end
