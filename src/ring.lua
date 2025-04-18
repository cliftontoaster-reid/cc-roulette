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

-- ==============================
-- Configuration and Initialization
-- ==============================
local mon = nil
local ring = {}
local ballPos = 1
local lastBallPos = { x = nil, y = nil }
local Tracer = require("src.trace") -- Add Tracer require

-- ==============================
-- Constants
-- ==============================
local RING_SIZE = 36
local ELEMENT_WIDTH = 6
local ELEMENT_HEIGHT = 3
local SPACING_X = ELEMENT_WIDTH
local SPACING_Y = ELEMENT_HEIGHT
local START_X = 4
local START_Y = 4

-- Colors
local COLOR = {
	BG = colors.green,
	RED = colors.red,
	BLACK = colors.black,
	WHITE = colors.white,
	BLUE = colors.blue,
	GRAY = colors.gray,
	LIGHT = colors.lightGray,
}

-- ==============================
-- Helper Functions
-- ==============================

---Checks if a coordinate is within monitor bounds
---@param x number X coordinate
---@param y number Y coordinate
---@param parentId string|nil Optional parent trace ID
---@return boolean inBounds True if coordinates are within monitor bounds
local function isInBounds(x, y, parentId)
	if mon == nil then return false end -- Add nil check
	local tr = Tracer.new()
	tr:setName("ring.isInBounds")
	tr:addTag("x", string.format("%d", x))
	tr:addTag("y", string.format("%d", y))
	if parentId then
		tr:setParentId(parentId)
	end

	local monW, monH = mon.getSize()
	local result = x >= 1 and x <= monW and y >= 1 and y <= monH

	tr:addAnnotation(string.format("Result: %s", tostring(result)))
	Tracer.addSpan(tr:endSpan())
	return result
end

---Draws a single element on the monitor
---@param x number Left position
---@param y number Top position
---@param color number Color from colors table
---@param number number|nil Optional number to display in the element
---@param parentId string|nil Optional parent trace ID
local function drawElement(x, y, color, number, parentId)
	if mon == nil then return end -- Add nil check
	local tr = Tracer.new()
	tr:setName("ring.drawElement")
	tr:addTag("x", string.format("%d", x))
	tr:addTag("y", string.format("%d", y))
	tr:addTag("color", string.format("%d", color))
	tr:addTag("number", number and string.format("%d", number) or "nil")
	if parentId then
		tr:setParentId(parentId)
	end

	-- Draw a rectangle
	mon.setBackgroundColor(color)
	mon.setTextColor(COLOR.WHITE)

	for i = 0, ELEMENT_WIDTH - 1 do
		for j = 0, ELEMENT_HEIGHT - 1 do
			mon.setCursorPos(x + i, y + j)
			mon.write(" ")
		end
	end

	-- Center the number in the element if provided
	if number == nil then
		tr:addAnnotation("No number provided")
		Tracer.addSpan(tr:endSpan())
		return
	end

	local numberX = x + math.floor(ELEMENT_WIDTH / 2)
	if number >= 10 then
		numberX = numberX - 1
	end

	mon.setCursorPos(numberX, y + math.floor(ELEMENT_HEIGHT / 2))
	mon.write(tostring(number))
	tr:addAnnotation(string.format("Drew number %d", number))
	Tracer.addSpan(tr:endSpan())
end

---Draws a ball element on the monitor
---@param x number Left position
---@param y number Top position
---@param parentId string|nil Optional parent trace ID
local function drawBallElement(x, y, parentId)
	if mon == nil then return end -- Add nil check
	local tr = Tracer.new()
	tr:setName("ring.drawBallElement")
	tr:addTag("x", string.format("%d", x))
	tr:addTag("y", string.format("%d", y))
	if parentId then
		tr:setParentId(parentId)
	end

	local ball = {
		"  00  ",
		"000000",
		"  00  ",
	}

	for i = 1, #ball do
		for j = 1, #ball[i] do
			mon.setCursorPos(x + j - 1, y + i - 1)
			mon.setBackgroundColor(ball[i]:sub(j, j) == "0" and COLOR.BLUE or COLOR.BG)
			mon.write(" ")
		end
	end
	tr:addAnnotation("Ball element drawn")
	Tracer.addSpan(tr:endSpan())
end

---Converts a roulette number to x,y coordinates
---@param number number The roulette number (1-36)
---@param parentId string|nil Optional parent trace ID
---@return number|nil x The x coordinate
---@return number|nil y The y coordinate
local function numberToPos(number, parentId)
	if mon == nil then return nil, nil end -- Add nil check
	local tr = Tracer.new()
	tr:setName("ring.numberToPos")
	tr:addTag("number", string.format("%d", number))
	if parentId then
		tr:setParentId(parentId)
	end

	local posx = START_X + ELEMENT_WIDTH
	local posy = START_Y + ELEMENT_HEIGHT
	local newx, newy

	if number <= 10 then
		newx = posx + (number - 1) * SPACING_X
		newy = posy
	elseif number <= 19 then
		newx = posx + SPACING_X * 9
		newy = posy + (number - 10) * SPACING_Y
	elseif number <= 28 then
		newx = posx + SPACING_X * 9 - (number - 19) * SPACING_X
		newy = posy + SPACING_Y * 9
	elseif number <= 36 then
		newx = posx
		newy = posy + SPACING_Y * 9 - (number - 28) * SPACING_Y
	else
		tr:addAnnotation("Invalid number")
		Tracer.addSpan(tr:endSpan())
		return nil, nil
	end

	tr:addAnnotation(string.format("Calculated pos: (%d, %d)", newx, newy))
	Tracer.addSpan(tr:endSpan())
	return newx, newy
end

---Draws a line on the monitor
---@param startX number Start X coordinate
---@param startY number Start Y coordinate
---@param endX number End X coordinate
---@param endY number End Y coordinate
---@param color number|nil Optional color (defaults to white)
---@param thickness number|nil Optional line thickness (defaults to 1)
---@param parentId string|nil Optional parent trace ID
local function drawLine(startX, startY, endX, endY, color, thickness, parentId)
	if mon == nil then return end -- Add nil check
	local tr = Tracer.new()
	tr:setName("ring.drawLine")
	tr:addTag("startX", string.format("%d", startX))
	tr:addTag("startY", string.format("%d", startY))
	tr:addTag("endX", string.format("%d", endX))
	tr:addTag("endY", string.format("%d", endY))
	tr:addTag("color", color and string.format("%d", color) or "nil")
	tr:addTag("thickness", thickness and string.format("%d", thickness) or "nil")
	if parentId then
		tr:setParentId(parentId)
	end

	mon.setBackgroundColor(color or COLOR.WHITE)
	thickness = thickness or 1

	local dx = math.abs(endX - startX)
	local dy = math.abs(endY - startY)
	local sx = startX < endX and 1 or -1
	local sy = startY < endY and 1 or -1
	local err = dx - dy
	local x, y = startX, startY
	local halfThick = math.floor(thickness / 2)
	local pixelsDrawn = 0

	while true do
		if thickness == 1 then
			if isInBounds(x, y, tr.traceId) then
				mon.setCursorPos(x, y)
				mon.write(" ")
				pixelsDrawn = pixelsDrawn + 1
			end
		else
			-- Draw perpendicular to the major axis for thickness
			if dx >= dy then -- More horizontal
				for i = -halfThick, halfThick do
					local drawY = y + i
					if isInBounds(x, drawY, tr.traceId) then
						mon.setCursorPos(x, drawY)
						mon.write(" ")
						pixelsDrawn = pixelsDrawn + 1
					end
				end
			else -- More vertical
				for i = -halfThick, halfThick do
					local drawX = x + i
					if isInBounds(drawX, y, tr.traceId) then
						mon.setCursorPos(drawX, y)
						mon.write(" ")
						pixelsDrawn = pixelsDrawn + 1
					end
				end
			end
		end

		-- Check if we've reached the end point
		if x == endX and y == endY then
			break
		end

		-- Calculate next position
		local e2 = 2 * err
		if e2 > -dy then
			err = err - dy
			x = x + sx
		end
		if e2 < dx then
			err = err + dx
			y = y + sy
		end
	end
	tr:addAnnotation(string.format("Drew %d pixels", pixelsDrawn))
	Tracer.addSpan(tr:endSpan())
end

---Draws a sequence of elements in a row or column
---@param startNum number Starting number
---@param count number Number of elements to draw
---@param startX number Starting X position
---@param startY number Starting Y position
---@param incrementX number X increment between elements
---@param incrementY number Y increment between elements
---@param parentId string|nil Optional parent trace ID
local function drawSequence(startNum, count, startX, startY, incrementX, incrementY, parentId)
	if mon == nil then return end -- Add nil check (indirect usage via drawElement)
	local tr = Tracer.new()
	tr:setName("ring.drawSequence")
	tr:addTag("startNum", string.format("%d", startNum))
	tr:addTag("count", string.format("%d", count))
	tr:addTag("startX", string.format("%d", startX))
	tr:addTag("startY", string.format("%d", startY))
	tr:addTag("incrementX", string.format("%d", incrementX))
	tr:addTag("incrementY", string.format("%d", incrementY))
	if parentId then
		tr:setParentId(parentId)
	end

	local x, y = startX, startY
	for i = 0, count - 1 do
		local num = startNum + i
		drawElement(x, y, num % 2 == 0 and COLOR.RED or COLOR.BLACK, num, tr.traceId)
		x = x + incrementX
		y = y + incrementY
	end
	tr:addAnnotation(string.format("Drew %d elements", count))
	Tracer.addSpan(tr:endSpan())
end

---Draws the ball at a specific roulette number position
---@param number number Roulette number position
---@param parentId string|nil Optional parent trace ID
local function drawBall(number, parentId)
	if mon == nil then return end -- Add nil check (indirect usage via drawElement/drawBallElement)
	local tr = Tracer.new()
	tr:setName("ring.drawBall")
	tr:addTag("number", string.format("%d", number))
	if parentId then
		tr:setParentId(parentId)
	end

	local x, y = numberToPos(number, tr.traceId)
	if x == nil or y == nil then
		tr:addAnnotation("Invalid number, cannot draw ball")
		Tracer.addSpan(tr:endSpan())
		return
	end

	-- Clear the last ball position
	if lastBallPos.x ~= nil then
		tr:addAnnotation(string.format("Clearing last ball at (%d, %d)", lastBallPos.x, lastBallPos.y))
		drawElement(lastBallPos.x, lastBallPos.y, COLOR.BG, nil, tr.traceId)
	end

	-- Draw the new ball
	tr:addAnnotation(string.format("Drawing new ball at (%d, %d)", x, y))
	drawBallElement(x, y, tr.traceId)

	-- Remember this position
	lastBallPos.x = x
	lastBallPos.y = y
	Tracer.addSpan(tr:endSpan())
end

---Draws the decorative middle area of the roulette board
---@param startX number Starting X position
---@param startY number Starting Y position
---@param parentId string|nil Optional parent trace ID
local function drawMiddleDecoration(startX, startY, parentId)
	if mon == nil then return end -- Add nil check (indirect usage via drawLine/isInBounds)
	local tr = Tracer.new()
	tr:setName("ring.drawMiddleDecoration")
	tr:addTag("startX", string.format("%d", startX))
	tr:addTag("startY", string.format("%d", startY))
	if parentId then
		tr:setParentId(parentId)
	end

	-- Calculate the center of the ring
	local endX = SPACING_X * 12 + START_X - 1
	local endY = SPACING_Y * 12 + START_Y - 1
	local centerX = (startX + endX) / 2
	local centerY = (startY + endY) / 2

	local writableStartX = startX + ELEMENT_WIDTH * 2
	local writableEndX = endX - ELEMENT_WIDTH * 2
	local writableStartY = startY + ELEMENT_HEIGHT * 2
	local writableEndY = endY - ELEMENT_HEIGHT * 2

	-- Ball size
	local ballRadius = 4

	-- Draw a line at the horizontal center going from left to right
	drawLine(writableStartX, centerY, writableEndX, centerY, COLOR.WHITE, 1, tr.traceId)

	-- Draw a line at the vertical center going from top to bottom
	drawLine(centerX, writableStartY, centerX, writableEndY, COLOR.WHITE, 1, tr.traceId)

	-- Write a diagonal line from top-left to bottom-right
	drawLine(writableStartX, writableStartY, writableEndX, writableEndY, COLOR.WHITE, 1, tr.traceId)

	-- Write a diagonal line from top-right to bottom-left
	drawLine(writableEndX, writableStartY, writableStartX, writableEndY, COLOR.WHITE, 1, tr.traceId)

	-- Draw a square around the center, with a line encasing the entire writable area
	drawLine(writableStartX, writableStartY, writableEndX, writableStartY, COLOR.LIGHT, 1, tr.traceId)
	drawLine(writableStartX, writableStartY, writableStartX, writableEndY, COLOR.LIGHT, 1, tr.traceId)
	drawLine(writableEndX, writableStartY, writableEndX, writableEndY, COLOR.LIGHT, 1, tr.traceId)
	drawLine(writableStartX, writableEndY, writableEndX, writableEndY, COLOR.LIGHT, 1, tr.traceId)

	-- Draw the central ball
	mon.setBackgroundColor(COLOR.GRAY)
	local circlePixels = 0
	for y = -ballRadius, ballRadius do
		for x = -ballRadius, ballRadius do
			-- Check if point is within circle
			if x * x + y * y <= ballRadius * ballRadius then
				local drawX = centerX + x
				local drawY = centerY + y
				if isInBounds(drawX, drawY, tr.traceId) then
					mon.setCursorPos(drawX, drawY)
					mon.write(" ")
					circlePixels = circlePixels + 1
				end
			end
		end
	end
	tr:addAnnotation(string.format("Drew center decoration, circle pixels: %d", circlePixels))
	Tracer.addSpan(tr:endSpan())
end

-- ==============================
-- Main Drawing Functions
-- ==============================

---Draws the complete roulette ring
---@param parentId string|nil Optional parent trace ID
local function drawRing(parentId)
	if mon == nil then return end -- Add nil check
	local tr = Tracer.new()
	tr:setName("ring.drawRing")
	if parentId then
		tr:setParentId(parentId)
	end

	mon.setBackgroundColor(COLOR.BG)
	mon.clear()

	-- Calculate positions
	local endX = SPACING_X * 11 + START_X
	local endY = SPACING_Y * 11 + START_Y
	local midX = endX - ELEMENT_WIDTH
	local midY = endY - ELEMENT_HEIGHT

	-- Draw corners
	drawElement(START_X, START_Y, COLOR.BLACK, nil, tr.traceId)
	drawElement(START_X + ELEMENT_WIDTH, START_Y, COLOR.BLACK, 1, tr.traceId)
	drawElement(START_X, START_Y + ELEMENT_HEIGHT, COLOR.BLACK, 1, tr.traceId)

	-- Draw top row (2-9)
	drawSequence(2, 8, START_X + 2 * ELEMENT_WIDTH, START_Y, SPACING_X, 0, tr.traceId)

	-- Draw top-right corner
	drawElement(midX, START_Y, COLOR.RED, 10, tr.traceId)
	drawElement(endX, START_Y, COLOR.RED, nil, tr.traceId)
	drawElement(endX, START_Y + ELEMENT_HEIGHT, COLOR.RED, 10, tr.traceId)

	-- Draw right column (11-18)
	drawSequence(11, 8, endX, START_Y + 2 * ELEMENT_HEIGHT, 0, SPACING_Y, tr.traceId)

	-- Draw bottom-right corner
	drawElement(endX, midY, COLOR.BLACK, 19, tr.traceId)
	drawElement(endX, endY, COLOR.BLACK, nil, tr.traceId)
	drawElement(midX, endY, COLOR.BLACK, 19, tr.traceId)

	-- Draw bottom row (20-27)
	drawSequence(20, 8, midX - ELEMENT_WIDTH, endY, -SPACING_X, 0, tr.traceId)

	-- Draw bottom-left corner
	drawElement(START_X + ELEMENT_WIDTH, endY, COLOR.RED, 28, tr.traceId)
	drawElement(START_X, endY, COLOR.RED, nil, tr.traceId)
	drawElement(START_X, midY, COLOR.RED, 28, tr.traceId)

	-- Draw left column (29-36)
	drawSequence(29, 8, START_X, midY - ELEMENT_HEIGHT, 0, -SPACING_Y, tr.traceId)

	-- Draw the decorative middle
	drawMiddleDecoration(START_X, START_Y, tr.traceId)

	tr:addAnnotation("Ring drawn")
	Tracer.addSpan(tr:endSpan())
end

---Animates the ball movement with easing
---@param force number How many positions to move
---@param parentId string|nil Optional parent trace ID
---@return number The final ball position
local function launchBall(force, parentId)
	if mon == nil then return ballPos end -- Add nil check, return current pos
	local tr = Tracer.new()
	tr:setName("ring.launchBall")
	tr:addTag("force", string.format("%d", force))
	tr:addTag("startPos", string.format("%d", ballPos))
	if parentId then
		tr:setParentId(parentId)
	end

	-- Pre-calculate final position
	local newBallPos = (ballPos + force) % RING_SIZE
	if newBallPos == 0 then
		newBallPos = RING_SIZE
	end
	tr:addTag("finalPos", string.format("%d", newBallPos))

	-- Draw the ring once before animation
	drawRing(tr.traceId)

	-- Define animation parameters
	local minSleep = 0.01
	local maxSleep = 0.45
	local sleepRange = maxSleep - minSleep

	-- Easing function for smooth animation
	local function ease(step)
		if step < 0.8 then
			return 0.5 * step / 0.8
		else
			return 0.5 + 0.5 * (1 - math.pow(1 - (step - 0.8) / 0.2, 3))
		end
	end

	-- Animate through every position
	for step = 1, force do
		-- Calculate current position
		local currentPos = (ballPos + step) % RING_SIZE
		if currentPos == 0 then
			currentPos = RING_SIZE
		end

		-- Draw the ball at each position
		drawBall(currentPos, tr.traceId)

		-- Add a tiny bit of randomness to the sleep time
		local randomFactor = math.random() * 0.02 - 0.01
		local sleepTime = minSleep + ease(step / force) * sleepRange + randomFactor
		sleep(sleepTime)
	end

	-- Update ball position to final location
	ballPos = newBallPos
	tr:addAnnotation(string.format("Animation complete, final position: %d", ballPos))

	-- Make the winning number blink
	local x, y = numberToPos(ballPos, tr.traceId)
	if x and y then
		local originalColor = ballPos % 2 == 0 and COLOR.RED or COLOR.BLACK
		local blinkCount = 10
		tr:addAnnotation(string.format("Blinking winning number %d times", blinkCount))

		for i = 1, blinkCount do
			-- Invert colors
			drawElement(x, y, COLOR.WHITE, ballPos, tr.traceId)
			mon.setTextColor(originalColor)
			local numberX = x + math.floor(ELEMENT_WIDTH / 2)
			if ballPos >= 10 then
				numberX = numberX - 1
			end
			mon.setCursorPos(numberX, y + math.floor(ELEMENT_HEIGHT / 2))
			mon.write(tostring(ballPos))
			sleep(0.3)

			-- Return to original
			drawElement(x, y, originalColor, ballPos, tr.traceId)
			sleep(0.3)
		end

		-- Draw ball at final position
		drawBall(ballPos, tr.traceId)
		tr:addAnnotation("Blinking finished")
	else
		tr:addAnnotation("Could not get position for blinking")
	end
	Tracer.addSpan(tr:endSpan())
	return ballPos
end

-- ==============================
-- Main Program Loop
-- ==============================

local ring = {}

-- Public API
ring.drawRing = function()
	drawRing()
end
ring.launchBall = function(force)
	return launchBall(force)
end
ring.drawBall = function(number)
	drawBall(number)
end
ring.numberToPos = function(number)
	return numberToPos(number)
end

-- Getters
function ring.getBallPosition()
	local tr = Tracer.new()
	tr:setName("ring.getBallPosition")
	tr:addAnnotation(string.format("Current ball position: %d", ballPos))
	Tracer.addSpan(tr:endSpan())
	return ballPos
end

---Initializes the ring with a monitor peripheral
---@param monitor string The name of the monitor peripheral
function ring.init(monitor)
	local tr = Tracer.new()
	tr:setName("ring.init")
	tr:addTag("monitor", monitor)

	mon = peripheral.wrap(monitor)

	-- Monitor validation
	if mon == nil then
		tr:addAnnotation("Monitor not found")
		Tracer.addSpan(tr:endSpan())
		error("Monitor not found", 0)
		return
	end
	if not mon.isColour() then
		tr:addAnnotation("Monitor is not color")
		Tracer.addSpan(tr:endSpan())
		error("Monitor is not color", 0)
		return
	end

	local w, h = mon.getSize()
	tr:addTag("monitorWidth", string.format("%d", w))
	tr:addTag("monitorHeight", string.format("%d", h))
	-- Center the ring on the monitor
	local totalWidth = SPACING_X * 12
	local totalHeight = SPACING_Y * 12

	START_X = math.floor((w - totalWidth) / 2)
	START_Y = math.floor((h - totalHeight) / 2)

	-- Ensure minimum margins
	START_X = math.max(START_X, 2)
	START_Y = math.max(START_Y, 2)
	tr:addTag("startX", string.format("%d", START_X))
	tr:addTag("startY", string.format("%d", START_Y))

	mon.setTextScale(0.5)

	drawRing(tr.traceId)
	drawBall(ballPos, tr.traceId)
	tr:addAnnotation("Initialization complete")
	Tracer.addSpan(tr:endSpan())
	return ring
end

-- Return the module
return ring
