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
local Logger = require("src.log")
local Tracer = require("src.trace")

---@class Bet
---@field amount number
---@field color number
---@field player string | nil
---@field uuid string | nil
---@field number number

---@type Bet[]
local bets = {}

-- Global variables for display configuration
local NUMBER_SPACING = 6                          -- Distance between numbers
local NUMBER_WIDTH = 4                            -- Width of the number display area
local DOZEN_WIDTH = 6                             -- Width for dozen columns (1st 12, etc.)
local SPECIAL_SPACING = (NUMBER_SPACING * 12) / 6 -- Distance between special displays
local SPECIAL_WIDTH = SPECIAL_SPACING * 0.85      -- Width of the special display area
local MAX_BETS = 4

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
	["19 to 36"] = 59,
}

-- Define the table layout
local layout = {
	{
		rowPos = 1,
		items = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 },
		special = "1st 12",
		spacing = NUMBER_SPACING,
		itemWidth = NUMBER_WIDTH,
		specialWidth = DOZEN_WIDTH,
	},
	{
		rowPos = 1 + (MAX_BETS + 2) * 1,
		items = { 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24 },
		special = "2nd 12",
		spacing = NUMBER_SPACING,
		itemWidth = NUMBER_WIDTH,
		specialWidth = DOZEN_WIDTH,
	},
	{
		rowPos = 1 + (MAX_BETS + 2) * 2,
		items = { 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36 },
		special = "3rd 12",
		spacing = NUMBER_SPACING,
		itemWidth = NUMBER_WIDTH,
		specialWidth = DOZEN_WIDTH,
	},
	{
		rowPos = 1 + (MAX_BETS + 2) * 3,
		items = { "1 to 18", "19 to 36", "Even", "Red", "Black", "Odd" },
		spacing = SPECIAL_SPACING,
		itemWidth = SPECIAL_WIDTH,
	},
}

---@param nbr number The bet number to print
---@param idx number Where to start printing the bets
---@param posx number The x position to print the bets
---@param parentId string|nil The parent trace ID for logging
---@return nil
local function printBet(nbr, idx, posx, parentId)
	local tr = Tracer.new()
	tr:setName("carpet.printBet")
	tr:addTag("nbr", string.format("%d", nbr))
	tr:addTag("idx", string.format("%d", idx))
	tr:addTag("posx", string.format("%d", posx))
	if parentId then
		tr:setParentId(parentId)
	end

	if mon == nil then
		tr:addAnnotation("Monitor not initialized")
		Tracer.addSpan(tr:endSpan())
		return
	end

	local usedBets = {}

	for _, v in pairs(bets) do
		if v.number == nbr then
			Logger.debug("Match found: adding bet from " .. v.player .. " for " .. v.amount)
			table.insert(usedBets, v)
		end
	end

	tr:addAnnotation(string.format("Found %d bets for number %d", #usedBets, nbr))

	for i = 1, #usedBets do
		local v = usedBets[i]
		Logger.debug(
			"Printing bet "
			.. i
			.. " at position "
			.. posx
			.. ","
			.. (idx + i)
			.. ": "
			.. v.amount
			.. " from "
			.. v.player
		)
		-- The numbers should appear under the number
		mon.setCursorPos(posx, idx + i)
		mon.setBackgroundColour(v.color)
		mon.write(" ")
		mon.setBackgroundColour(colours.green)
		mon.write(" " .. v.amount)
	end
	Tracer.addSpan(tr:endSpan())
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
---@param parentId string|nil The parent trace ID for logging
---@return nil
local function printRow(rowDef, parentId)
	local tr = Tracer.new()
	tr:setName("carpet.printRow")
	tr:addTag("rowPos", string.format("%d", rowDef.rowPos))
	if parentId then
		tr:setParentId(parentId)
	end

	if mon == nil then
		tr:addAnnotation("Monitor not initialized")
		Tracer.addSpan(tr:endSpan())
		return
	end

	mon.setCursorPos(1, rowDef.rowPos)

	-- Print the regular items in the row
	for i, item in ipairs(rowDef.items) do
		local posx = 2 + (i - 1) * rowDef.spacing

		-- Set color based on whether it's a number or special item
		if type(item) == "number" then
			mon.setBackgroundColour(item % 2 == 0 and colours.red or colours.black)
		else
			mon.setBackgroundColour((i % 2 == 0) and colours.red or colours.black)
		end

		mon.setCursorPos(posx, rowDef.rowPos + 1)
		mon.write(formatDisplayText(item, rowDef.itemWidth))

		-- Determine the bet number - either the number itself or its special value
		local betNumber = type(item) == "number" and item or specialValues[item]
		printBet(betNumber, rowDef.rowPos + 2, posx, tr.traceId) -- Pass traceId
	end

	-- Print the special column if specified
	if rowDef.special then
		local posx = 2 + (#rowDef.items * rowDef.spacing)
		mon.setCursorPos(posx, rowDef.rowPos + 1)
		mon.setBackgroundColour(colours.black)
		-- Use specialWidth if defined, otherwise fall back to itemWidth
		local displayWidth = rowDef.specialWidth or rowDef.itemWidth
		mon.write(formatDisplayText(rowDef.special, displayWidth))
		printBet(specialValues[rowDef.special], rowDef.rowPos + 2, posx, tr.traceId) -- Pass traceId
	end
	Tracer.addSpan(tr:endSpan())
end

---@param parentId string|nil The parent trace ID for logging
local function update(parentId)
	local tr = Tracer.new()
	tr:setName("carpet.update")
	if parentId then
		tr:setParentId(parentId)
	end

	if mon == nil then
		tr:addAnnotation("Monitor not initialized")
		Tracer.addSpan(tr:endSpan())
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
		printRow(rowDef, tr.traceId) -- Pass traceId
	end
	Tracer.addSpan(tr:endSpan())
end

--- Finds the clicked number or special value based on the x and y coordinates in the layout.
---
---@param x number The x-coordinate of the click position.
---@param y number The y-coordinate of the click position.
---@param parentId string|nil The parent trace ID for logging
---@return number|nil Returns the number corresponding to the clicked item, or a special value if the special column was clicked.
local function findClickedNumber(x, y, parentId)
	local tr = Tracer.new()
	tr:setName("carpet.findClickedNumber")
	tr:addTag("x", string.format("%d", x))
	tr:addTag("y", string.format("%d", y))
	if parentId then
		tr:setParentId(parentId)
	end

	-- Check each row in the layout to find what was clicked
	for _, rowDef in ipairs(layout) do
		-- Check if click is within the row's vertical bounds
		-- Using MAX_BETS + 2 for consistency with row spacing in layout definition
		if y >= rowDef.rowPos and y <= rowDef.rowPos + MAX_BETS + 2 then
			-- Check for regular items
			for i, item in ipairs(rowDef.items) do
				local itemX = 2 + (i - 1) * rowDef.spacing
				local itemWidth = rowDef.itemWidth

				-- If click is within this item's bounds
				if x >= itemX and x < itemX + itemWidth then
					local clickedItem = type(item) == "number" and item or specialValues[item]
					tr:addAnnotation(string.format("Clicked item %s (value %d)", tostring(item), clickedItem))
					Tracer.addSpan(tr:endSpan())
					return clickedItem
				end
			end

			-- Check for special column if defined
			if rowDef.special then
				local specialX = 2 + (#rowDef.items * rowDef.spacing)
				local specialWidth = rowDef.specialWidth or rowDef.itemWidth

				-- If click is within the special column bounds
				if x >= specialX and x < specialX + specialWidth then
					local clickedItem = specialValues[rowDef.special]
					tr:addAnnotation(string.format("Clicked special %s (value %d)", rowDef.special, clickedItem))
					Tracer.addSpan(tr:endSpan())
					return clickedItem
				end
			end
		end
	end

	-- No valid area was clicked
	tr:addAnnotation("No valid area clicked")
	Tracer.addSpan(tr:endSpan())
	return nil
end

---@param amount number The amount to bet
---@param color number The color of the bet
---@param player string The player who placed the bet
---@param number number The number to bet on
---@param parentId string|nil The parent trace ID for logging
---@return nil
local function addBet(amount, color, player, number, parentId)
	local tr = Tracer.new()
	tr:setName("carpet.addBet")
	tr:addTag("amount", string.format("%d", amount))
	tr:addTag("color", string.format("%d", color))
	tr:addTag("player", player)
	tr:addTag("number", string.format("%d", number))
	if parentId then
		tr:setParentId(parentId)
	end

	Logger.info("Adding bet: " .. amount .. " from player " .. player .. " on number " .. number)

	-- Check if the player has already placed a bet on this number
	---@type Bet
	local existingBet = nil
	for i, v in pairs(bets) do
		Logger.debug("Checking bet " .. i .. " from player " .. v.player)
		if v.player == player and v.number == number then
			existingBet = v
			Logger.info("Found existing bet from " .. player .. " on number " .. number)
			tr:addAnnotation("Found existing bet")
			break
		end
	end

	if existingBet then
		Logger.info("Updating existing bet from " ..
			player .. " from " .. existingBet.amount .. " to " .. (existingBet.amount + amount))
		existingBet.amount = existingBet.amount + amount
		tr:addAnnotation("Updated existing bet")
	else
		Logger.info("Creating new bet for " .. player .. " of " .. amount .. " on number " .. number)
		table.insert(bets, { amount = amount, color = color, player = player, number = number })
		tr:addAnnotation("Created new bet")
	end
	update(tr.traceId) -- Pass traceId
	Logger.info("Bet added successfully")
	Tracer.addSpan(tr:endSpan())
end

local grid = {}

---@param monitorName string
---@param parentId string|nil The parent trace ID for logging
function grid.init(monitorName, parentId)
	local tr = Tracer.new()
	tr:setName("carpet.init")
	tr:addTag("monitorName", monitorName)
	if parentId then
		tr:setParentId(parentId)
	end

	mon = peripheral.wrap(monitorName)
	Logger.info("Looking for monitor peripheral...")

	if mon == nil then
		tr:addAnnotation("Monitor not found")
		Tracer.addSpan(tr:endSpan())
		error("Monitor not found", 0)
		return
	end
	Logger.info("Monitor found: " .. peripheral.getName(mon))
	tr:addAnnotation("Monitor found: " .. peripheral.getName(mon))

	if not mon.isColour() then
		tr:addAnnotation("Monitor is not color")
		Tracer.addSpan(tr:endSpan())
		error("Monitor is not color", 0)
		return
	end
	Logger.info("Monitor supports color")
	tr:addAnnotation("Monitor supports color")

	Logger.info("Setting monitor text scale to 0.7")
	mon.setTextScale(0.7)

	local w, h = mon.getSize()
	Logger.info("Monitor size: " .. w .. "x" .. h)
	tr:addAnnotation(string.format("Monitor size: %dx%d", w, h))
	update(tr.traceId) -- Pass traceId
	Tracer.addSpan(tr:endSpan())
end

---@param bet Bet The bet to remove
---@param parentId string|nil The parent trace ID for logging
local function removeBet(bet, parentId)
	local tr = Tracer.new()
	tr:setName("carpet.removeBet")
	tr:addTag("player", bet.player or "nil")
	tr:addTag("amount", string.format("%d", bet.amount))
	tr:addTag("number", string.format("%d", bet.number))
	if parentId then
		tr:setParentId(parentId)
	end

	local removed = false
	for i, v in ipairs(bets) do
		if v == bet then
			table.remove(bets, i)
			removed = true
			tr:addAnnotation("Bet removed")
			break
		end
	end
	if not removed then
		tr:addAnnotation("Bet not found")
	end
	update(tr.traceId) -- Pass traceId
	Tracer.addSpan(tr:endSpan())
end

grid.update = update
grid.getBets = function()
	-- No tracing needed for simple getter unless complex logic is added
	return bets
end
grid.findClickedNumber = findClickedNumber
grid.addBet = addBet
grid.removeBet = removeBet

---@param parentId string|nil The parent trace ID for logging
function grid.resetBets(parentId)
	local tr = Tracer.new()
	tr:setName("carpet.resetBets")
	if parentId then
		tr:setParentId(parentId)
	end
	bets = {}
	tr:addAnnotation("Bets reset")
	Tracer.addSpan(tr:endSpan())
	-- Optionally call update if the visual state needs immediate clearing
	-- update(tr.traceId)
end

return grid
