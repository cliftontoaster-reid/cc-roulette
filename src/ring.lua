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
local mon = peripheral.wrap("monitor_1")
local ring = {}
local ballPos = 1
local lastBallPos = { x = nil, y = nil }

-- Monitor validation
if mon == nil then
    error("Monitor not found", 0)
    return
end
if not mon.isColour() then
    error("Monitor is not color", 0)
    return
end

mon.setTextScale(0.5)

local w, h = mon.getSize()
if w < 88 or h < 44 then
    error("Monitor is too small, must be at least 88x44, and is " .. w .. "x" .. h, 0)
    return
end

-- ==============================
-- Constants
-- ==============================
local RING_SIZE = 36
local ELEMENT_WIDTH = 9
local ELEMENT_HEIGHT = 6
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
    GRAY = colors.gray
}

-- ==============================
-- Helper Functions
-- ==============================

---Checks if a coordinate is within monitor bounds
---@param x number X coordinate
---@param y number Y coordinate
---@return boolean inBounds True if coordinates are within monitor bounds
local function isInBounds(x, y)
    local monW, monH = mon.getSize()
    return x >= 1 and x <= monW and y >= 1 and y <= monH
end

---Draws a single element on the monitor
---@param x number Left position
---@param y number Top position
---@param color number Color from colors table
---@param number number|nil Optional number to display in the element
local function drawElement(x, y, color, number)
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
        return
    end

    local numberX = x + math.floor(ELEMENT_WIDTH / 2)
    if number >= 10 then
        numberX = numberX - 1
    end

    mon.setCursorPos(numberX, y + math.floor(ELEMENT_HEIGHT / 2))
    mon.write(tostring(number))
end

---Draws a ball element on the monitor
---@param x number Left position
---@param y number Top position
local function drawBallElement(x, y)
    local ball = {
        "   000   ",
        "  00000  ",
        " 0000000 ",
        " 0000000 ",
        "  00000  ",
        "   000   ",
    }

    for i = 1, #ball do
        for j = 1, #ball[i] do
            mon.setCursorPos(x + j - 1, y + i - 1)
            mon.setBackgroundColor(ball[i]:sub(j, j) == "0" and COLOR.BLUE or COLOR.BG)
            mon.write(" ")
        end
    end
end

---Converts a roulette number to x,y coordinates
---@param number number The roulette number (1-36)
---@return number|nil x The x coordinate
---@return number|nil y The y coordinate
local function numberToPos(number)
    local posx = START_X + ELEMENT_WIDTH
    local posy = START_Y + ELEMENT_HEIGHT

    if number <= 10 then
        local newx = posx + (number - 1) * SPACING_X
        return newx, posy
    elseif number <= 19 then
        local newy = posy + (number - 10) * SPACING_Y
        return posx + SPACING_X * 9, newy
    elseif number <= 28 then
        local newx = posx + SPACING_X * 9 - (number - 19) * SPACING_X
        return newx, posy + SPACING_Y * 9
    elseif number <= 36 then
        local newy = posy + SPACING_Y * 9 - (number - 28) * SPACING_Y
        return posx, newy
    else
        return nil, nil
    end
end

---Draws a line on the monitor
---@param startX number Start X coordinate
---@param startY number Start Y coordinate
---@param endX number End X coordinate
---@param endY number End Y coordinate
---@param color number|nil Optional color (defaults to white)
---@param thickness number|nil Optional line thickness (defaults to 1)
local function drawLine(startX, startY, endX, endY, color, thickness)
    mon.setBackgroundColor(color or COLOR.WHITE)
    thickness = thickness or 1

    local dx = math.abs(endX - startX)
    local dy = math.abs(endY - startY)
    local sx = startX < endX and 1 or -1
    local sy = startY < endY and 1 or -1
    local err = dx - dy
    local x, y = startX, startY
    local halfThick = math.floor(thickness / 2)

    while true do
        if thickness == 1 then
            if isInBounds(x, y) then
                mon.setCursorPos(x, y)
                mon.write(" ")
            end
        else
            -- Draw perpendicular to the major axis for thickness
            if dx >= dy then -- More horizontal
                for i = -halfThick, halfThick do
                    local drawY = y + i
                    if isInBounds(x, drawY) then
                        mon.setCursorPos(x, drawY)
                        mon.write(" ")
                    end
                end
            else -- More vertical
                for i = -halfThick, halfThick do
                    local drawX = x + i
                    if isInBounds(drawX, y) then
                        mon.setCursorPos(drawX, y)
                        mon.write(" ")
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
end

---Draws a sequence of elements in a row or column
---@param startNum number Starting number
---@param count number Number of elements to draw
---@param startX number Starting X position
---@param startY number Starting Y position
---@param incrementX number X increment between elements
---@param incrementY number Y increment between elements
local function drawSequence(startNum, count, startX, startY, incrementX, incrementY)
    local x, y = startX, startY
    for i = 0, count - 1 do
        local num = startNum + i
        drawElement(x, y, num % 2 == 0 and COLOR.RED or COLOR.BLACK, num)
        x = x + incrementX
        y = y + incrementY
    end
end

---Draws the ball at a specific roulette number position
---@param number number Roulette number position
local function drawBall(number)
    local x, y = numberToPos(number)
    if x == nil or y == nil then
        return
    end

    -- Clear the last ball position
    if lastBallPos.x ~= nil then
        drawElement(lastBallPos.x, lastBallPos.y, COLOR.BG, nil)
    end

    -- Draw the new ball
    drawBallElement(x, y)

    -- Remember this position
    lastBallPos.x = x
    lastBallPos.y = y
end

---Draws the decorative middle area of the roulette board
---@param startX number Starting X position
---@param startY number Starting Y position
local function drawMiddleDecoration(startX, startY)
    local middleSizeX = 12
    local middleSizeY = 12
    local ringSizeX = ELEMENT_WIDTH * 12
    local ringSizeY = ELEMENT_HEIGHT * 12

    local middleX = startX + (ringSizeX - middleSizeX) / 2
    local middleY = startY + (ringSizeY - middleSizeY) / 2

    -- Points for drawing
    local left = startX + (ELEMENT_WIDTH * 2)
    local top = startY + (ELEMENT_HEIGHT * 2)
    local right = left + (middleSizeX * 6) - 1
    local bottom = top + (middleSizeY * 4) - 1
    local midX = middleX + middleSizeX / 2

    -- Draw horizontal line across middle
    drawLine(left, middleY + middleSizeY / 2, right, middleY + middleSizeY / 2, COLOR.WHITE, 1)

    -- Draw vertical line through middle
    drawLine(midX, top, midX, bottom, COLOR.WHITE, 1)

    -- Draw diagonal lines
    drawLine(left, top, right, bottom, COLOR.WHITE, 2)
    drawLine(right, top, left, bottom, COLOR.WHITE, 2)

    -- Draw outer square
    drawLine(left, top, right, top, COLOR.WHITE, 1)
    drawLine(right, top, right, bottom, COLOR.WHITE, 1)
    drawLine(right, bottom, left, bottom, COLOR.WHITE, 1)
    drawLine(left, bottom, left, top, COLOR.WHITE, 1)

    -- Draw circle in the middle
    mon.setBackgroundColor(COLOR.GRAY)
    for i = 0, middleSizeX - 1 do
        for j = 0, middleSizeY - 1 do
            if (i - middleSizeX / 2) ^ 2 + (j - middleSizeY / 2) ^ 2 < (middleSizeX / 2) ^ 2 then
                mon.setCursorPos(middleX + i, middleY + j)
                mon.write(" ")
            end
        end
    end
end

-- ==============================
-- Main Drawing Functions
-- ==============================

---Draws the complete roulette ring
local function drawRing()
    mon.setBackgroundColor(COLOR.BG)
    mon.clear()

    -- Calculate positions
    local endX = SPACING_X * 11 + START_X
    local endY = SPACING_Y * 11 + START_Y
    local midX = endX - ELEMENT_WIDTH
    local midY = endY - ELEMENT_HEIGHT

    -- Draw corners
    drawElement(START_X, START_Y, COLOR.BLACK, nil)
    drawElement(START_X + ELEMENT_WIDTH, START_Y, COLOR.BLACK, 1)
    drawElement(START_X, START_Y + ELEMENT_HEIGHT, COLOR.BLACK, 1)

    -- Draw top row (2-9)
    drawSequence(2, 8, START_X + 2 * ELEMENT_WIDTH, START_Y, SPACING_X, 0)

    -- Draw top-right corner
    drawElement(midX, START_Y, COLOR.RED, 10)
    drawElement(endX, START_Y, COLOR.RED, nil)
    drawElement(endX, START_Y + ELEMENT_HEIGHT, COLOR.RED, 10)

    -- Draw right column (11-18)
    drawSequence(11, 8, endX, START_Y + 2 * ELEMENT_HEIGHT, 0, SPACING_Y)

    -- Draw bottom-right corner
    drawElement(endX, midY, COLOR.BLACK, 19)
    drawElement(endX, endY, COLOR.BLACK, nil)
    drawElement(midX, endY, COLOR.BLACK, 19)

    -- Draw bottom row (20-27)
    drawSequence(20, 8, midX - ELEMENT_WIDTH, endY, -SPACING_X, 0)

    -- Draw bottom-left corner
    drawElement(START_X + ELEMENT_WIDTH, endY, COLOR.RED, 28)
    drawElement(START_X, endY, COLOR.RED, nil)
    drawElement(START_X, midY, COLOR.RED, 28)

    -- Draw left column (29-36)
    drawSequence(29, 8, START_X, midY - ELEMENT_HEIGHT, 0, -SPACING_Y)

    -- Draw the decorative middle
    drawMiddleDecoration(START_X, START_Y)
end

---Animates the ball movement with easing
---@param force number How many positions to move
local function launchBall(force)
    -- Pre-calculate final position
    local newBallPos = (ballPos + force) % RING_SIZE
    if newBallPos == 0 then newBallPos = RING_SIZE end

    -- Draw the ring once before animation
    drawRing()

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
        if currentPos == 0 then currentPos = RING_SIZE end

        -- Draw the ball at each position
        drawBall(currentPos)

        -- Add a tiny bit of randomness to the sleep time
        local randomFactor = math.random() * 0.02 - 0.01
        local sleepTime = minSleep + ease(step / force) * sleepRange + randomFactor
        sleep(sleepTime)
    end

    -- Update ball position to final location
    ballPos = newBallPos

    -- Make the winning number blink
    local x, y = numberToPos(ballPos)
    if x and y then
        local originalColor = ballPos % 2 == 0 and COLOR.RED or COLOR.BLACK
        local blinkCount = 10

        for i = 1, blinkCount do
            -- Invert colors
            drawElement(x, y, COLOR.WHITE, ballPos)
            mon.setTextColor(originalColor)
            local numberX = x + math.floor(ELEMENT_WIDTH / 2)
            if ballPos >= 10 then
                numberX = numberX - 1
            end
            mon.setCursorPos(numberX, y + math.floor(ELEMENT_HEIGHT / 2))
            mon.write(tostring(ballPos))
            sleep(0.3)

            -- Return to original
            drawElement(x, y, originalColor, ballPos)
            sleep(0.3)
        end

        -- Draw ball at final position
        drawBall(ballPos)
    end
end

-- ==============================
-- Main Program Loop
-- ==============================

local ring = {}

-- Public API
ring.drawRing = drawRing
ring.launchBall = launchBall
ring.drawBall = drawBall
ring.numberToPos = numberToPos

-- Getters
function ring.getBallPosition()
    return ballPos
end

-- Initialize the ring
function ring.init()
    drawRing()
    drawBall(ballPos)
    return ring
end

-- Return the module
return ring
