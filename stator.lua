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

---@class ServerDevice
---@field modem string The device that is used as modem
---@field chatBox string The device that is used as chat

---@class ServerConfig
---@field version string The version of the config file schema using Semantic Versioning
---@field devices ServerDevice The devices that are used in the server

---@class PlayerEntry
---@field player string
---@field balance number

local toml = require("src.toml")
local configPath = "/sconfig.toml"

---@type ServerConfig
local config

local db = require("src.database")
local modem = require("src.modem")
local chat

db.init("/.db/")

---@return ServerConfig
local function loadConfig()
	local file = fs.open(configPath, "r")
	config = toml.parse(file.readAll())

	file.close()
	return config
end

local function defaultConfig()
	---@type ServerConfig
	local config = {
		version = "0.1.0",
		devices = {
			modem = "top",
			chatBox = "bottom",
			playerDetector = "left",
		},
	}

	return config
end

local function saveConfig()
	local file = fs.open(configPath, "w")
	file.write(toml.encode(config))
	file.close()
end

local function playersInBorders(startPos, endPos)
	-- Get all players within the defined coordinates
	local players = peripheral.call(config.devices.playerDetector, "getPlayersInCoords", startPos, endPos)
	return players or {}
end

local function isInside(username, startPos, endPos)
	-- Check if specific player is inside the defined area
	local players = playersInBorders(startPos, endPos)
	for _, player in ipairs(players) do
		if player == username then
			return true
		end
	end
	return false
end

local function getSpursAmount()
	--- read inventory at redstone
	local inv = peripheral.call(config.devices.redstone, "list")
	if inv == nil then
		return 0
	end

	local spurs = 0
	for _, item in ipairs(inv) do
		-- later on do check for item named
		spurs = spurs + item.count
	end
	return spurs
end

local function getPlayer(player)
	if db.existsQuery("players", { player = player }) then
		return db.getQuery("players", { player = player })
	else
		local playerEntry = {
			player = player,
			balance = 0,
		}
		db.insert("players", playerEntry)
		return playerEntry
	end

	return nil
end

local function init()
	if fs.exists(configPath) then
		loadConfig()
	else
		config = defaultConfig()
		saveConfig()
		error("Config file not found. Created default config file at " .. configPath)
	end

	chat = peripheral.wrap(config.devices.chatBox)
	if chat == nil then
		error("ChatBox not found", 0)
		return
	end
end

init()

local function string_ends_with(str, suffix)
	return str:find(suffix, -#suffix, true) ~= nil
end

local function handleMessage(channel, reply, message)
	if not (channel == 1 and reply == 1) then
		return
	end

	-- Check if the message type ends with "Res" to determine if it is a response
	if string_ends_with(message.type, "Res") then
		return
	end
	local response = {
		type = "genRes",
		code = 404,
		message = "Unknown message type",
	}

	if message.type == "win" then
		---@type PlayerEntry|nil
		local pl = getPlayer(message.player)
		if pl == nil then
			print("Player not found")
			local new = { player = message.player, balance = 0 }
			db.create("players", message.player, new)

			pl = new
		end

		pl.balance = pl.balance + message.payout
		local succ, err = db.update("players", pl.player, pl)
		local ret
		if not succ then
			ret = {
				code = 500,
				message = "Error updating player balance: " .. err,
			}
			print(ret.message)
		else
			ret = {
				code = 200,
				message = "Player balance updated successfully",
			}
			print(ret.message)
		end

		-- Send a response back to the sender
		response = {
			type = "winRes",
			code = ret.code,
			message = ret.message,
		}
	elseif message.type == "balance" then
		local pl = getPlayer(message.player)
		if pl == nil then
			print("Player not found")
			response = {
				type = "balanceRes",
				code = 404,
				message = "Player not found",
			}
		else
			response = {
				type = "balanceRes",
				code = 200,
				message = "Player balance retrieved successfully",
				balance = pl.balance,
			}
		end
	elseif message.type == "resetBalance" then
		local pl = getPlayer(message.player)
		if pl == nil then
			print("Player not found")
			response = {
				type = "resetBalanceRes",
				code = 200, -- As we are reseting the balance, if the player is not found, we can consider it a success
				message = "Player not found",
			}
		else
			pl.balance = 0
			local succ, err = db.update("players", pl.player, pl)
			local ret
			if not succ then
				ret = {
					code = 500,
					message = "Error updating player balance: " .. err,
				}
				print(ret.message)
			else
				ret = {
					code = 200,
					message = "Player balance reset successfully",
				}
				print(ret.message)
			end

			response = {
				type = "resetBalanceRes",
				code = ret.code,
				message = ret.message,
			}
		end
	elseif message.type == "playersInSquare" then
		local startPos = message.startPos
		local endPos = message.endPos

		local players = playersInBorders(startPos, endPos)

		response = {
			type = "playersInSquareRes",
			code = 200,
			players = players,
			numberOfPlayers = #players,
		}
	end

	modem.transmit(1, 1, response)
end

while true do
	local event, side, channel, reply, message = os.pullEvent("modem_message")
	if event == "modem_message" then
		handleMessage(channel, reply, message)
	end
end
