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

local mon = peripheral.find("monitor")
print("Looking for monitor peripheral...")

if mon == nil then
    error("Monitor not found", 0)
    return
end
print("Monitor found: " .. peripheral.getName(mon))

if not mon.isColour() then
    error("Monitor is not color", 0)
    return
end
print("Monitor supports color")

print("Setting monitor text scale to 0.7")
mon.setTextScale(1)

local w, h = mon.getSize()
print("Monitor size: " .. w .. "x" .. h)

local grid = {}

---@class Bet
---@field amount number
---@field color number
---@field player string
---@field number number

---@type Bet[]
local bets = {}

---@param nbr number The number of the bets to print, don't ask
---@param idx number Where to start printing the bets
---@param posx number The x position to print the bets
---@return nil
local function printBet(nbr, idx, posx)
    local usedBets = {}

    for i, v in pairs(bets) do
        if v.number == nbr then
            print("Match found: adding bet from " .. v.player .. " for " .. v.amount)
            table.insert(usedBets, v)
        end
    end

    for i = 1, #usedBets do
        local v = usedBets[i]
        print("Printing bet " ..
            i .. " at position " .. posx .. "," .. (idx + i) .. ": " .. v.amount .. " from " .. v.player)
        -- The numbers should appear under the number
        mon.setCursorPos(posx, idx + i)
        mon.setBackgroundColour(v.color)
        mon.write(" ")
        mon.setBackgroundColour(colours.green)
        mon.write(" " .. v.amount)
    end
end

-- Global variables for number display configuration
local NUMBER_SPACING = 9   -- Distance between numbers
local NUMBER_WIDTH = 6     -- Width of the number display area
local SPECIAL_SPACING = 12 -- Distance between special displays
local SPECIAL_WIDTH = 10   -- Width of the special display area

-- Helper function to print a range of numbers
---@param rowPos number The row to print the numbers on
---@param startNum number The first number to print
---@param endNum number The last number to print
---@return nil
local function printNumberRange(rowPos, startNum, endNum)
    mon.setCursorPos(1, rowPos)
    for i = startNum, endNum do
        local posx = (i - startNum) * NUMBER_SPACING
        local ncol = (i % 2 == 0) and colours.red or colours.black
        mon.setBackgroundColour(ncol)

        -- Format based on number range
        local numStr
        if i < 10 then
            numStr = string.rep(" ", (NUMBER_WIDTH) / 2) .. i .. string.rep(" ", (NUMBER_WIDTH - 1) / 2)
        else
            numStr = string.rep(" ", (NUMBER_WIDTH - 2) / 2) .. i .. string.rep(" ", (NUMBER_WIDTH - 2) / 2)
        end

        mon.setCursorPos(posx + 2, rowPos + 1)
        mon.write(numStr)

        printBet(i, rowPos + 2, posx + 2)
    end
end

-- Assign values above 50 for special options
local specialValues = {
    ["1st 12"] = 51,
    ["2nd 12"] = 52, -- Fixed typo from "2st" to "2nd"
    ["3rd 12"] = 53, -- Fixed typo from "3st" to "3rd"
    ["1 to 18"] = 54,
    ["Even"] = 55,
    ["Red"] = 56,
    ["Black"] = 57,
    ["Odd"] = 58,
    ["19 to 36"] = 59
}

local special = {
    "1st 12", "2nd 12", "3rd 12", -- Fixed typos
    "1 to 18", "Even", "Red",
    "Black", "Odd", "19 to 36"
}

local function printSpecial(rowPos, startNum, endNum)
    mon.setCursorPos(1, rowPos)
    for i = startNum, endNum do
        local posx = (i - startNum) * SPECIAL_SPACING
        local ncol = (i % 2 == 0) and colours.red or colours.black
        mon.setBackgroundColour(ncol)

        -- Format based on special label
        local label = special[i - startNum + 1]
        local strLen = string.len(label)
        local leftPad = math.floor((SPECIAL_WIDTH - strLen) / 2)
        local rightPad = SPECIAL_WIDTH - strLen - leftPad
        local numStr = string.rep(" ", leftPad) .. label .. string.rep(" ", rightPad)

        mon.setCursorPos(posx + 2, rowPos + 1)
        mon.write(numStr)

        -- Print bet using the special value instead of position
        printBet(specialValues[label], rowPos + 2, posx + 2)
    end
end

local function update()
    mon.clear()
    mon.setBackgroundColour(colours.green)
    mon.setTextColour(colours.white)
    -- fill the screen with green
    for i = 1, h do
        mon.setCursorPos(1, i)
        mon.write(string.rep(" ", w))
    end

    -- Print the three number ranges
    printNumberRange(1, 1, 12)
    printNumberRange(11, 13, 24)
    printNumberRange(21, 25, 36)

    -- Print the special bets
    printSpecial(31, 1, 9)
end

local function findClickedNumber(x, y)
    -- Check for regular numbers (1-36) first
    if y >= 1 and y <= 10 then
        -- First row: Numbers 1-12
        local col = math.floor((x - 2) / NUMBER_SPACING)
        if col >= 0 and col < 12 then
            return col + 1
        end
    elseif y >= 11 and y <= 20 then
        -- Second row: Numbers 13-24
        local col = math.floor((x - 2) / NUMBER_SPACING)
        if col >= 0 and col < 12 then
            return col + 13
        end
    elseif y >= 21 and y <= 30 then
        -- Third row: Numbers 25-36
        local col = math.floor((x - 2) / NUMBER_SPACING)
        if col >= 0 and col < 12 then
            return col + 25
        end
    elseif y >= 31 and y <= 40 then
        -- Special bets row
        local col = math.floor((x - 2) / SPECIAL_SPACING)
        if col >= 0 and col < 9 then
            local specialName = special[col + 1]
            if specialName then
                return specialValues[specialName]
            end
        end
    end

    -- No valid area was clicked
    return nil
end

grid.update = update
grid.bets = bets
grid.findClickedNumber = findClickedNumber

update()

return grid
