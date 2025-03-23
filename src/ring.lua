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

local mon = peripheral.wrap("monitor_1")
local ballPos = 1

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

local ring = {}
local ringSize = 36

-- Define block size variables globally
local elementWidth = 9
local elementHeight = 6
local spacingX = elementWidth
local spacingY = elementHeight

local function drawElement(x, y, color, number)
    -- Draw a 6x3 rectangle
    mon.setBackgroundColor(color)
    mon.setTextColor(colors.white)

    for i = 0, elementWidth - 1 do
        for j = 0, elementHeight - 1 do
            mon.setCursorPos(x + i, y + j)
            mon.write(" ")
        end
    end

    -- Center the number in the block
    if number == nil then
        return
    end
    if number < 10 then
        mon.setCursorPos(x + math.floor(elementWidth / 2), y + math.floor(elementHeight / 2))
    else
        mon.setCursorPos(x + math.floor(elementWidth / 2) - 1, y + math.floor(elementHeight / 2))
    end
    mon.write(tostring(number))
end

local function drawBallElement(x, y, color)
    -- Draw a 9x6 circle
    local ball = {
        "   000   ",
        "  00000  ",
        " 0000000 ",
        " 0000000 ",
        "  00000  ",
        "   000   ",
    }

    -- Print the  0 as a white background space, and spaces, as green background spaces
    for i = 1, #ball do
        for j = 1, #ball[i] do
            mon.setCursorPos(x + j - 1, y + i - 1)
            mon.setBackgroundColor(ball[i]:sub(j, j) == "0" and colors.blue or colors.green)
            mon.write(" ")
        end
    end
end

-- Takes the number and returns where the square in the ring should be
-- so that in the inner ring, 1 is at the top left, 2 is just to the right of 1, etc
-- until you went all the way around the inner ring, then you start on the outer ring
-- the outer ring being the ones with the numbers
local function numberToPos(number)
    local posx = 4 + elementWidth
    local posy = 4 + elementHeight

    if number <= 10 then
        local newx = posx + (number - 1) * spacingX
        return newx, posy
    elseif number <= 19 then
        local newy = posy + (number - 10) * spacingY
        return posx + spacingX * 9, newy
    elseif number <= 28 then
        local newx = posx + spacingX * 9 - (number - 19) * spacingX
        return newx, posy + spacingY * 9
    elseif number <= 36 then
        local newy = posy + spacingY * 9 - (number - 28) * spacingY
        return posx, newy
    else
        return nil, nil
    end
end

-- Keep track of the last ball position
local lastBallPos = { x = nil, y = nil }

local function drawBall(number)
    local x, y = numberToPos(number)
    if x == nil then
        return
    end

    -- Clear the last ball position only
    if lastBallPos.x ~= nil then
        drawElement(lastBallPos.x, lastBallPos.y, colors.green, nil)
    end

    -- Draw the new ball
    drawBallElement(x, y)

    -- Remember this position as the last ball position
    lastBallPos.x = x
    lastBallPos.y = y
end

local function drawLine(startX, startY, endX, endY, color, thickness)
    -- Set color
    mon.setBackgroundColor(color or colors.white)

    -- Default thickness to 1 if not provided
    thickness = thickness or 1

    -- Get monitor dimensions
    local monW, monH = mon.getSize()

    -- Function to check if a point is within monitor bounds
    local function isInBounds(x, y)
        return x >= 1 and x <= monW and y >= 1 and y <= monH
    end

    -- Calculate line parameters
    local dx = math.abs(endX - startX)
    local dy = math.abs(endY - startY)
    local sx = startX < endX and 1 or -1
    local sy = startY < endY and 1 or -1

    -- Decision variable for Bresenham's algorithm
    local err = dx - dy

    -- Current position
    local x, y = startX, startY

    -- For thicker lines
    local halfThick = math.floor(thickness / 2)

    while true do
        -- For thickness of 1, just draw the single pixel
        if thickness == 1 then
            if isInBounds(x, y) then
                mon.setCursorPos(x, y)
                mon.write(" ")
            end
        else
            -- For thicker lines, draw perpendicular to the major axis
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

local function drawRing()
    mon.setBackgroundColor(colors.green)
    mon.clear()

    -- Define positioning
    local startX = 4
    local startY = 4
    local endX = spacingX * 11 + startX
    local endY = spacingY * 11 + startY
    local midX = endX - elementWidth
    local midY = endY - elementHeight

    -- Helper function to draw a sequence of elements
    local function drawSequence(startNum, count, startX, startY, incrementX, incrementY)
        local x, y = startX, startY
        for i = 0, count - 1 do
            local num = startNum + i
            drawElement(x, y, num % 2 == 0 and colors.red or colors.black, num)
            x = x + incrementX
            y = y + incrementY
        end
    end

    -- Draw the first corner (top-left)
    drawElement(startX, startY, colors.black, nil)
    drawElement(startX + elementWidth, startY, colors.black, 1)
    drawElement(startX, startY + elementHeight, colors.black, 1)

    -- Draw top row (2-9)
    drawSequence(2, 8, startX + 2 * elementWidth, startY, spacingX, 0)

    -- Draw top-right corner
    drawElement(midX, startY, colors.red, 10)
    drawElement(endX, startY, colors.red, nil)
    drawElement(endX, startY + elementHeight, colors.red, 10)

    -- Draw right column (11-18)
    drawSequence(11, 8, endX, startY + 2 * elementHeight, 0, spacingY)

    -- Draw bottom-right corne
    drawElement(endX, midY, colors.black, 19)
    drawElement(endX, endY, colors.black, nil)
    drawElement(midX, endY, colors.black, 19)

    -- Draw bottom row (20-27)
    drawSequence(20, 8, midX - elementWidth, endY, -spacingX, 0)

    -- Draw bottom-left corner
    drawElement(startX + elementWidth, endY, colors.red, 28)
    drawElement(startX, endY, colors.red, nil)
    drawElement(startX, midY, colors.red, 28)

    -- Draw left column (29-36)
    drawSequence(29, 8, startX, midY - elementHeight, 0, -spacingY)
    --- PRETTY MIDDLE
    local middleSizeX = 12
    local middleSizeY = 12
    local ringSizeX = elementWidth * 12
    local ringSizeY = elementHeight * 12

    local middleX = startX + (ringSizeX - middleSizeX) / 2
    local middleY = startY + (ringSizeY - middleSizeY) / 2

    -- Draw a horizontal line across the middle, 7 elements long
    drawLine(
        startX + (elementWidth * 2),
        middleY + middleSizeY / 2,
        startX + (elementWidth * 2) + (middleSizeX * 6) - 1,
        middleY + middleSizeY / 2,
        colors.white,
        1
    )

    -- Draw a vertical line through the middle
    drawLine(
        middleX + middleSizeX / 2,
        startY + (elementHeight * 2),
        middleX + middleSizeX / 2,
        startY + (elementHeight * 2) + (middleSizeY * 4) - 1,
        colors.white,
        1
    )

    -- Draw a diagonal line from the min of both horizontal and vertical lines
    -- to their combined end, as well as the opposite
    drawLine(
        startX + (elementWidth * 2),
        startY + (elementHeight * 2),
        startX + (elementWidth * 2) + (middleSizeX * 6) - 1,
        startY + (elementHeight * 2) + (middleSizeY * 4) - 1,
        colors.white,
        2
    )

    drawLine(
        startX + (elementWidth * 2) + (middleSizeX * 6) - 1,
        startY + (elementHeight * 2),
        startX + (elementWidth * 2),
        startY + (elementHeight * 2) + (middleSizeY * 4) - 1,
        colors.white,
        2
    )

    -- Now make a square that uses every end of the diagonal lines as a corner
    drawLine(
        startX + (elementWidth * 2),
        startY + (elementHeight * 2),
        startX + (elementWidth * 2) + (middleSizeX * 6) - 1,
        startY + (elementHeight * 2),
        colors.white,
        1
    )
    drawLine(
        startX + (elementWidth * 2) + (middleSizeX * 6) - 1,
        startY + (elementHeight * 2),
        startX + (elementWidth * 2) + (middleSizeX * 6) - 1,
        startY + (elementHeight * 2) + (middleSizeY * 4) - 1,
        colors.white,
        1
    )
    drawLine(
        startX + (elementWidth * 2) + (middleSizeX * 6) - 1,
        startY + (elementHeight * 2) + (middleSizeY * 4) - 1,
        startX + (elementWidth * 2),
        startY + (elementHeight * 2) + (middleSizeY * 4) - 1,
        colors.white,
        1
    )
    drawLine(
        startX + (elementWidth * 2),
        startY + (elementHeight * 2) + (middleSizeY * 4) - 1,
        startX + (elementWidth * 2),
        startY + (elementHeight * 2),
        colors.white,
        1
    )


    -- Draw a circle at the middle of the ring, make it grey
    mon.setBackgroundColor(colors.gray)
    for i = 0, middleSizeX - 1 do
        for j = 0, middleSizeY - 1 do
            if (i - middleSizeX / 2) ^ 2 + (j - middleSizeY / 2) ^ 2 < (middleSizeX / 2) ^ 2 then
                mon.setCursorPos(middleX + i, middleY + j)
                mon.write(" ")
            end
        end
    end
end

local function launchBall(force)
    -- Pre-calculate final position
    local newBallPos = (ballPos + force) % ringSize
    if newBallPos == 0 then newBallPos = ringSize end

    -- Draw the ring once before animation
    drawRing()

    -- Define animation parameters
    local minSleep = 0.01
    local maxSleep = 0.45
    local sleepRange = maxSleep - minSleep

    -- Define easeInOutQuad function
    local function ease(step)
        if step < 0.8 then
            return 0.5 * step / 0.8
        else
            return 0.5 + 0.5 * (1 - math.pow(1 - (step - 0.8) / 0.2, 3))
        end
    end

    -- Animate through every single position
    for step = 1, force do
        print("Step: " .. step .. " of " .. force)
        -- Calculate current position
        local currentPos = (ballPos + step) % ringSize
        if currentPos == 0 then currentPos = ringSize end

        -- Draw the ball at each position
        drawBall(currentPos)

        -- Add a tiny bit of randomness to the sleep time
        local randomFactor = math.random() * 0.02 - 0.01
        local sleepTime = minSleep + ease(step / force) * sleepRange + randomFactor
        print("Sleeping for " .. sleepTime)
        sleep(sleepTime)
    end

    -- Update ball position to final location
    ballPos = newBallPos
end

drawRing()
drawBall(ballPos)

while true do
    launchBall(math.random(150, 200))
    sleep(2)
end
