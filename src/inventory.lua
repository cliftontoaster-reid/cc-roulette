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
local invside = "bottom"

local Logger = require("src.log")
local Tracer = require("src.trace")

---@type table<number, IvMnager>
local invManagers = {}

local inv = {}

---Gets the amount of money (emeralds) a player has in their off-hand
---@param idx number The player index in invManagers
---@param parentId string|nil The parent trace ID for logging
---@return number|nil The count of money items, or nil if player not found, no item in off-hand, or item is not money
local function getMoneyInPlayer(idx, parentId)
	local tr = Tracer.new()
	tr:setName("inventory.getMoneyInPlayer")
	tr:addTag("idx", string.format("%d", idx))
	if parentId then
		tr:setParentId(parentId)
	end

	local player = invManagers[idx + 1]
	if not player then
		Logger.debug("Player %d not found", idx)
		return nil
	end

	local success, item = pcall(function()
		local ptr = Tracer.new()
		ptr:setName("getItemInOffHand")
		ptr:addTag("idx", string.format("%d", idx))
		ptr:setParentId(tr.traceId)

		local hand = player:getItemInOffHand()

		ptr:addAnnotation(hand.name or "nil")
		Tracer.addSpan(ptr:endSpan())
		return hand
	end)

	---@type number | nil
	local amount = item.count or 0

	if not success or not item then
		Logger.debug("No item in off-hand for player %d", idx)
		tr:addAnnotation("No item in off-hand")
		amount = nil
	end
	if item.name ~= money then
		Logger.debug("Item in off-hand is not money: %s", item.name)
		tr:addAnnotation("Item in off-hand is not money")
		amount = nil
	end
	Tracer.addSpan(tr:endSpan())
	return amount
end

---Removes a specified amount of money from a player
---@param idx number The player index in invManagers
---@param amount number The amount of money to take from the player
---@param parentId string|nil The parent trace ID for logging
---@return number|nil The amount taken if successful, nil if player not found or has insufficient funds
local function takeMoneyFromPlayer(idx, amount, parentId)
	local tr = Tracer.new()
	tr:setName("inventory.takeMoneyFromPlayer")
	tr:addTag("idx", string.format("%d", idx))
	tr:addTag("amount", string.format("%d", amount))
	if parentId then
		tr:setParentId(parentId)
	end
	if amount <= 0 then
		Logger.debug("Amount must be greater than 0")
		tr:addAnnotation("Amount must be greater than 0")
		Tracer.addSpan(tr:endSpan())
		return nil
	end

	local player = invManagers[idx + 1]
	if not player then
		tr:addAnnotation("Player not found")
		Logger.debug("Player %d not found", idx)
		Tracer.addSpan(tr:endSpan())
		return nil
	end

	local count = getMoneyInPlayer(idx, tr.traceId) -- Pass the traceId here
	if not count or count < amount then
		tr:addAnnotation("Not enough money")
		Logger.debug("Not enough money in player %d: %d < %d", idx, count or 0, amount)
		Tracer.addSpan(tr:endSpan())
		return nil
	end

	local success, result = pcall(function()
		local ptr = Tracer.new()
		ptr:setName("removeItemFromPlayer")
		ptr:addTag("idx", string.format("%d", idx))
		ptr:addTag("amount", string.format("%d", amount))
		ptr:setParentId(tr.traceId)

		local removedCount = player.removeItemFromPlayer(invside, {
			name = money,
			count = amount,
		})

		ptr:addAnnotation(string.format("Removed %d", removedCount or -1))
		Tracer.addSpan(ptr:endSpan())
		return removedCount
	end)

	---@type number | nil
	local retres = amount

	if not success then
		Logger.debug("Failed to take money from player %d", idx)
		tr:addAnnotation("Failed to take money")
		retres = nil
	end
	if result ~= amount then
		Logger.debug("Failed to take %d money from player %s, took %d", amount, inv.getPlayer(idx), result)
		tr:addAnnotation(string.format("Failed to take %d money", amount))
		retres = nil
	end
	Logger.debug("Successfully took %d money from player %s", amount, inv.getPlayer(idx))
	return retres
end

---Adds a specified amount of money to a player
---@param idx number The player index in invManagers
---@param amount number The amount of money to add to the player
---@param parentId string|nil The parent trace ID for logging
---@return number|nil The amount added if successful, nil if player not found or adding fails
local function addMoneyToPlayer(idx, amount, parentId)
	local tr = Tracer.new()
	tr:setName("inventory.addMoneyToPlayer")
	tr:addTag("idx", string.format("%d", idx))
	tr:addTag("amount", string.format("%d", amount))
	if parentId then
		tr:setParentId(parentId)
	end
	if amount <= 0 then
		Logger.debug("Amount must be greater than 0")
		tr:addAnnotation("Amount must be greater than 0")
		Tracer.addSpan(tr:endSpan())
		return nil
	end

	local player = invManagers[idx + 1]
	if not player then
		Logger.debug("Player %d not found", idx)
		tr:addAnnotation("Player not found")
		Tracer.addSpan(tr:endSpan())
		return nil
	end

	local success, res = pcall(function()
		local ptr = Tracer.new()
		ptr:setName("addItemToPlayer")
		ptr:addTag("idx", string.format("%d", idx))
		ptr:addTag("amount", string.format("%d", amount))
		ptr:setParentId(tr.traceId)

		local gave = player.addItemToPlayer(invside, {
			name = money,
			count = amount,
		})

		ptr:addAnnotation(string.format("Added %d", gave or -1))
		Tracer.addSpan(ptr:endSpan())

		return gave
	end)

	---@type number | nil
	local retres = amount -- Initialize with the intended return value

	if not success then
		Logger.debug("Failed to add money to player %d", idx)
		tr:addAnnotation("Failed to add money")
		retres = nil
	elseif res ~= amount then
		Logger.debug("Added %d money to player %d, but expected %d", res or -1, idx, amount)
		tr:addAnnotation(string.format("Failed to add %d money, added %d", amount, res or -1))
		-- take back the money given
		local takeBackSuccess = pcall(function()
			local ptr = Tracer.new()
			ptr:setName("removeItemFromPlayer (rollback)")
			ptr:addTag("idx", string.format("%d", idx))
			ptr:addTag("amount", string.format("%d", res or -1))
			ptr:setParentId(tr.traceId)

			player.removeItemFromPlayer(invside, {
				name = money,
				count = res,
			})

			ptr:addAnnotation("Rollback attempted")
			Tracer.addSpan(ptr:endSpan())
		end)
		if not takeBackSuccess then
			Logger.debug("Failed to take back money from player %d", idx)
			tr:addAnnotation("Rollback failed")
		end
		-- Even if takeBackSuccess fails, we still return nil
		retres = nil
	else
		Logger.debug("Added %d money to player %d", amount, idx)
		tr:addAnnotation(string.format("Successfully added %d money", amount))
	end

	Tracer.addSpan(tr:endSpan())
	return retres
end

---Gets a player's ownership information
---@param idx number The player index in invManagers
---@param parentId string|nil The parent trace ID for logging
---@return string|nil The player owner identifier, or nil if player not found
local function getPlayer(idx, parentId)
	local tr = Tracer.new()
	tr:setName("inventory.getPlayer")
	tr:addTag("idx", string.format("%d", idx))
	if parentId then
		tr:setParentId(parentId)
	end

	local player = invManagers[idx + 1]
	if not player then
		Logger.debug("Player %d not found", idx)
		tr:addAnnotation("Player not found")
		Tracer.addSpan(tr:endSpan())
		return nil
	end

	local success, own = pcall(function()
		local ptr = Tracer.new()
		ptr:setName("getOwner")
		ptr:addTag("idx", string.format("%d", idx))
		ptr:setParentId(tr.traceId)

		local owner = player.getOwner()

		ptr:addAnnotation(owner or "nil")
		Tracer.addSpan(ptr:endSpan())
		return owner
	end)

	if not success or not own then
		Logger.debug("Failed to get owner for player %d", idx)
		tr:addAnnotation("Failed to get owner")
		Tracer.addSpan(tr:endSpan())
		return nil
	end

	tr:addAnnotation(string.format("Owner: %s", own))
	Tracer.addSpan(tr:endSpan())
	return own
end

---Finds the first iv manager that is owned by player
---@param player string The player identifier
---@param parentId string|nil The parent trace ID for logging
---@return number|nil The index of the iv manager, or nil if not found
local function findPlayer(player, parentId)
	local tr = Tracer.new()
	tr:setName("inventory.findPlayer")
	tr:addTag("player", player)
	if parentId then
		tr:setParentId(parentId)
	end

	for idx, iv in pairs(invManagers) do
		local success, owner = pcall(function()
			local ptr = Tracer.new()
			ptr:setName("getOwner")
			ptr:addTag("idx", string.format("%d", idx))
			ptr:setParentId(tr.traceId)

			local own = iv.getOwner()

			ptr:addAnnotation(own or "nil")
			Tracer.addSpan(ptr:endSpan())
			return own
		end)
		if success and owner == player then
			Logger.debug("Found player %s at index %d", player, idx)
			tr:addAnnotation(string.format("Player found at index %d", idx))
			Tracer.addSpan(tr:endSpan())
			return idx
		elseif not success then
			Logger.debug("Failed to get owner for index %d", idx)
			tr:addAnnotation(string.format("Failed getOwner for index %d", idx))
		end
	end

	Logger.debug("Player %s not found", player)
	tr:addAnnotation("Player not found")
	Tracer.addSpan(tr:endSpan())
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
