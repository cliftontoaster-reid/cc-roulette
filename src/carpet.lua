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

local mon = nil

---@class Bet
---@field amount number
---@field color number
---@field player string | nil
---@field uuid string | nil
---@field number number

---@type Bet[]
local bets = {}

-- Global variables for display configuration
local NUMBER_SPACING = 9                          -- Distance between numbers
local NUMBER_WIDTH = 6                            -- Width of the number display area
local DOZEN_WIDTH = 10                            -- Width for dozen columns (1st 12, etc.)
local SPECIAL_SPACING = (NUMBER_SPACING * 12) / 6 -- Distance between special displays
local SPECIAL_WIDTH = SPECIAL_SPACING * 0.85      -- Width of the special display area

-- Assign values above 50 for special options
local specialValues = {
    ["1st 12"] = 51,
    ["2nd 12"] = 52,
    ["3rd 12"] = 53,
    ["1 to 18"] = 54,
    ["Even"] = 55,
    ["Red"] = 56,
    ["Black"] = 57,
    ["Odd"] = 58,
    ["19 to 36"] = 59
}

-- Define the table layout
local layout = {
    {
        rowPos = 1,
        items = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 },
        special = "1st 12",
        spacing = NUMBER_SPACING,
        itemWidth = NUMBER_WIDTH,
        specialWidth = DOZEN_WIDTH
    },
    {
        rowPos = 11,
        items = { 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24 },
        special = "2nd 12",
        spacing = NUMBER_SPACING,
        itemWidth = NUMBER_WIDTH,
        specialWidth = DOZEN_WIDTH
    },
    {
        rowPos = 21,
        items = { 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36 },
        special = "3rd 12",
        spacing = NUMBER_SPACING,
        itemWidth = NUMBER_WIDTH,
        specialWidth = DOZEN_WIDTH
    },
    {
        rowPos = 31,
        items = { "1 to 18", "19 to 36", "Even", "Red", "Black", "Odd" },
        spacing = SPECIAL_SPACING,
        itemWidth = SPECIAL_WIDTH
    }
}

---@param nbr number The bet number to print
---@param idx number Where to start printing the bets
---@param posx number The x position to print the bets
---@return nil
local function printBet(nbr, idx, posx)
    if mon == nil then
        return
    end

    local usedBets = {}

    for _, v in pairs(bets) do
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

---@param item any The item (number or text) to display
---@param width number The width of the display area
---@return string The formatted text with proper padding
local function formatDisplayText(item, width)
    local text = tostring(item)
    local strLen = string.len(text)
    local leftPad = math.floor((width - strLen) / 2)
    local rightPad = width - strLen - leftPad
    return string.rep(" ", leftPad) .. text .. string.rep(" ", rightPad)
end

---@param rowDef table The row definition containing position and items
---@return nil
local function printRow(rowDef)
    if mon == nil then
        return
    end

    mon.setCursorPos(1, rowDef.rowPos)

    -- Print the regular items in the row
    for i, item in ipairs(rowDef.items) do
        local posx = (i - 1) * rowDef.spacing

        -- Set color based on whether it's a number or special item
        if type(item) == "number" then
            mon.setBackgroundColour(item % 2 == 0 and colours.red or colours.black)
        else
            mon.setBackgroundColour((i % 2 == 0) and colours.red or colours.black)
        end

        mon.setCursorPos(posx + 2, rowDef.rowPos + 1)
        mon.write(formatDisplayText(item, rowDef.itemWidth))

        -- Determine the bet number - either the number itself or its special value
        local betNumber = type(item) == "number" and item or specialValues[item]
        printBet(betNumber, rowDef.rowPos + 2, posx + 2)
    end

    -- Print the special column if specified
    if rowDef.special then
        local posx = #rowDef.items * rowDef.spacing
        mon.setCursorPos(posx + 2, rowDef.rowPos + 1)
        mon.setBackgroundColour(colours.black)
        -- Use specialWidth if defined, otherwise fall back to itemWidth
        local displayWidth = rowDef.specialWidth or rowDef.itemWidth
        mon.write(formatDisplayText(rowDef.special, displayWidth))
        printBet(specialValues[rowDef.special], rowDef.rowPos + 2, posx + 2)
    end
end

local function update()
    if mon == nil then
        return
    end

    mon.clear()
    mon.setBackgroundColour(colours.green)
    mon.setTextColour(colours.white)

    -- Fill the screen with green
    local w, h = mon.getSize()
    for i = 1, h do
        mon.setCursorPos(1, i)
        mon.write(string.rep(" ", w))
    end

    -- Print all rows according to layout
    for _, rowDef in ipairs(layout) do
        printRow(rowDef)
    end
end
--- Finds the clicked number or special value based on the x and y coordinates in the layout.
---
---This function iterates over rows defined in the 'layout' to determine which item was clicked.
---It handles both regular items and optionally a special column defined per row.
---
---Regular items are determined by dividing the x-coordinate adjusted by an offset (here -2)
---by the spacing defined for the row, and then checking if the index is within bounds.
---
---For rows with a special column, if the click is outside the bounds of the regular items,
---the function checks if the click falls within the bounds allocated for the special column.
---
---@param x number The x-coordinate of the click position.
---@param y number The y-coordinate of the click position.
---@return number|nil Returns the number corresponding to the clicked item, or a special value if the special column was clicked.
---                   Returns nil if no valid clickable area was found.
local function findClickedNumber(x, y)
    -- Check each row in the layout to find what was clicked
    for _, rowDef in ipairs(layout) do
        if y >= rowDef.rowPos and y <= rowDef.rowPos + 9 then
            -- Check for regular items
            local col = math.floor((x - 2) / rowDef.spacing)
            if col >= 0 and col < #rowDef.items then
                local item = rowDef.items[col + 1]
                return type(item) == "number" and item or specialValues[item]
            end

            -- Check for special column
            if rowDef.special then
                local specialX = x - rowDef.spacing * #rowDef.items
                if specialX >= 0 and specialX <= (rowDef.specialWidth or rowDef.itemWidth) + 2 then
                    return specialValues[rowDef.special]
                end
            end
        end
    end

    -- No valid area was clicked
    return nil
end

---@param amount number The amount to bet
---@param color number The color of the bet
---@param player string The player who placed the bet
---@param number number The number to bet on
---@return nil
local function addBet(amount, color, player, number)
    -- Check if the player has already placed a bet on this number
    ---@type Bet
    local existingBet = nil
    for _, v in pairs(bets) do
        if v.player == player and v.number == number then
            existingBet = v
            break
        end
    end

    if existingBet then
        existingBet.amount = existingBet.amount + amount
    else
        table.insert(bets, { amount = amount, color = color, player = player, number = number })
    end
    update()
end

local grid = {}

---@param monitorName string
function grid.init(monitorName)
    mon = peripheral.wrap(monitorName)
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
    mon.setTextScale(0.7)

    local w, h = mon.getSize()
    print("Monitor size: " .. w .. "x" .. h)
    update()
end

grid.update = update
grid.bets = bets
grid.findClickedNumber = findClickedNumber
grid.addBet = addBet

return grid
