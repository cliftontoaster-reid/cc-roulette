--[[
    ToasterGen Spin

    Copyright (C) 2025 Clifton Toaster Reid <cliftontreid@duck.com>

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
]]

---@class IvMnager
---@field addItemToPlayer fun(direction: "top"|"bottom"|"left"|"right"|"front"|"back", item: table): number
---@field removeItemFromPlayer fun(direction: "top"|"bottom"|"left"|"right"|"front"|"back", item: table): number
---@field getArmor fun(): table
---@field getOwner fun(): string
---@field isPlayerEquipped fun(): boolean
---@field isWearing fun(slot: number): boolean
---@field getItemInHand fun(): table
---@field getItemInOffHand fun(): table
---@field getFreeSlot fun(): number
---@field isSpaceAvailable fun(): boolean
---@field getEmptySpace fun(): number

local money = "numismatics:sprocket"
local Logger = require("src.log")

---@type table<number, IvMnager>
local invManagers = {}

local inv = {}

---Gets the amount of money (emeralds) a player has in their off-hand
---@param idx number The player index in invManagers
---@return number|nil The count of money items, or nil if player not found, no item in off-hand, or item is not money
local function getMoneyInPlayer(idx)
	local player = invManagers[idx + 1]
	if not player then
		Logger.debug("Player %d not found", idx)
		return nil
	end

	local success, item = pcall(function()
		return player:getItemInOffHand()
	end)
	if not success or not item then
		Logger.debug("No item in off-hand for player %d", idx)
		return nil
	end
	if item.name ~= money then
		Logger.debug("Item in off-hand is not money: %s", item.name)
		return nil
	end
	return item.count
end

---Removes a specified amount of money from a player
---@param idx number The player index in invManagers
---@param amount number The amount of money to take from the player
---@return number|nil The amount taken if successful, nil if player not found or has insufficient funds
local function takeMoneyFromPlayer(idx, amount)
	local player = invManagers[idx + 1]
	if not player then
		return nil
	end

	local count = getMoneyInPlayer(idx)
	if not count or count < amount then
		return nil
	end

	local success, result = pcall(function()
		return player.removeItemFromPlayer("bottom", {
			name = money,
			count = amount,
		})
	end)

	if not success then
		return nil
	end
	if result ~= amount then
		Logger.debug("Failed to take %d money from player %d, took %d", amount, idx, result)
		return nil
	end
	return amount
end

---Adds a specified amount of money to a player
---@param idx number The player index in invManagers
---@param amount number The amount of money to add to the player
---@return number|nil The amount added if successful, nil if player not found or adding fails
local function addMoneyToPlayer(idx, amount)
	local player = invManagers[idx + 1]
	if not player then
		Logger.debug("Player %d not found", idx)
		return nil
	end

	local success, res = pcall(function()
		return player.addItemToPlayer("bottom", {
			name = money,
			count = amount,
		})
	end)

	if not success then
		Logger.debug("Failed to add money to player %d", idx)
		return nil
	end

	if res ~= amount then
		Logger.debug("Added %d money to player %d, but expected %d", res, idx, amount)
		-- take back the money given
		local takeBackSuccess = pcall(function()
			player.addItemToPlayer("bottom", {
				name = money,
				count = res,
			})
		end)
		if not takeBackSuccess then
			Logger.debug("Failed to take back money from player %d", idx)
		end
		-- Even if takeBackSuccess fails, we still return nil
		return nil
	end

	Logger.debug("Added %d money to player %d", amount, idx)
	return amount
end

---Gets a player's ownership information
---@param idx number The player index in invManagers
---@return string|nil The player owner identifier, or nil if player not found
local function getPlayer(idx)
	local player = invManagers[idx + 1]
	if not player then
		return nil
	end

	local success, own = pcall(function()
		return player.getOwner()
	end)
	if not success or not own then
		return nil
	end
	return own
end

---Finds the first iv manager that is owned by player
---@param player string The player identifier
---@return number|nil The index of the iv manager, or nil if not found
local function findPlayer(player)
	for idx, iv in pairs(invManagers) do
		local success, owner = pcall(function()
			return iv.getOwner()
		end)
		if success and owner == player then
			return idx
		end
	end
	return nil
end

local function init(config)
	if config == nil then
		error("Config is nil")
		return
	end

	-- assign the table<number, IvMnager> to invManagers using the config's
	-- table<number, string> as the key and the peripheral.wrap function to turn the
	-- string into a IvMnager

	for idx, name in pairs(config) do
		local player = peripheral.wrap(name)
		if player then
			invManagers[idx] = player
		else
			error("Peripheral " .. name .. " not found")
		end
	end
end

inv.getMoneyInPlayer = getMoneyInPlayer
inv.takeMoneyFromPlayer = takeMoneyFromPlayer
inv.addMoneyToPlayer = addMoneyToPlayer
inv.getPlayer = getPlayer
inv.findPlayer = findPlayer
inv.init = init

return inv
