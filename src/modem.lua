--[[
    ToasterGen Spin

    Copyright (C) 2025 Clifton Toaster Reid <cliftontreid@duck.com>

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
]]

-- Initializes a rednet modem and sets the modem to listen for messages

local ready = false
local db = require("src.database")

db.init("/.db/")

local modem = peripheral.find("modem")
modem.open(1)

---@class WinMessage
---@field type string
---@field player string
---@field bet Bet
---@field payout number

--- Sends a win message to the server and waits for a response
---@param player string The player's name
---@param bet Bet The bet object containing the amount and color
---@param payout number The payout amount
---@return number The response code from the server
local function sendWin(player, bet, payout)
	---@type WinMessage
	local message = {
		type = "win",
		player = player,
		bet = bet,
		payout = payout,
	}

	modem.transmit(1, 1, message)

	-- await the response
	local event, side, channel, reply, distance
	repeat
		event, side, channel, reply, distance = os.pullEvent("modem_message")
	until channel == 1 and reply.type == "winRes"

	if reply.code ~= 200 then
		print("Error: " .. reply.message)
	end
	return reply.code
end

--- Retrieves the balance for a player from the server
---@param player string The player's name
---@return number|nil balance The player's balance, or nil if not found
---@return number code The response code from the server
local function getBallance(player)
	local message = {
		type = "balance",
		player = player,
	}

	modem.transmit(1, 1, message)

	-- await the response
	local event, side, channel, reply, distance
	repeat
		event, side, channel, reply, distance = os.pullEvent("modem_message")
	until channel == 1 and reply.type == "balanceRes"

	return reply.balance, reply.code
end

--- Resets the balance for a player to zero
---@param player string The player's name
---@return number code The response code from the server
---@return string message The response message from the server
local function resetBallance(player)
	local message = {
		type = "resetBalance",
		player = player,
	}

	modem.transmit(1, 1, message)

	-- await the response
	local event, side, channel, reply, distance
	repeat
		event, side, channel, reply, distance = os.pullEvent("modem_message")
	until channel == 1 and reply.type == "resetBalanceRes"

	return reply.code, reply.message
end

--- Gets a list of players within a specified rectangular area
---@param startPos table The starting position {x, y, z} of the area
---@param endPos table The ending position {x, y, z} of the area
---@return table players List of player names in the area
---@return number count Number of players in the area
local function getPlayersInSquare(startPos, endPos)
	local message = {
		type = "playersInSquare",
		startPos = startPos,
		endPos = endPos,
	}

	modem.transmit(1, 1, message)

	-- await the response
	local event, side, channel, reply, distance
	repeat
		event, side, channel, reply, distance = os.pullEvent("modem_message")
	until channel == 1 and reply.type == "playersInSquareRes"

	return reply.players, reply.numberOfPlayers
end

return {
	isReady = function()
		return ready
	end,

	sendWin = sendWin,
	getBallance = getBallance,
	resetBallance = resetBallance,
	getPlayersInSquare = getPlayersInSquare,
}
