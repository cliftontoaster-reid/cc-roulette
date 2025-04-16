--[[
    ToasterGen Spin

    Copyright (C) 2025 Clifton Toaster Reid <cliftontreid@duck.com>

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
]]

local completion = require("cc.completion")
local expect = require "cc.expect".expect

local config = {}

local function choice_impl(text, choices, add_space)
	local results = {}
	for n = 1, #choices do
		local option = choices[n]
		if #option + (add_space and 1 or 0) > #text and option:sub(1, #text) == text then
			local result = option:sub(#text + 1)
			if add_space then
				table.insert(results, result .. " ")
			else
				table.insert(results, result)
			end
		end
	end
	return results
end

local function peripheral_extended(text, add_space)
	expect(1, text, "string")
	expect(2, add_space, "boolean", "nil")

	local perifs = peripheral.getNames();
	-- Add directions to the list of peripherals
	local sides = { "top", "bottom", "left", "right", "front", "back" }
	for _, side in ipairs(sides) do
		table.insert(perifs, side)
	end
	return choice_impl(text, perifs, add_space)
end

--- Asks the user for a yes or no response
---@param message string The message to display
---@return boolean
function config.askYesNo(message)
	local options = { "yes", "no" }
	while true do
		write(message .. " [Y/N]: ")
		local response = string.lower(read(nil, nil, function(text)
			return completion.choice(text, options)
		end))
		if response == "yes" or response == "y" then
			return true
		elseif response == "no" or response == "n" then
			return false
		end
	end
end

--- Asks the user for a peripheral
--- @param message string The message to display
--- @return string
function config.askPeripheral(message, expectedType)
	expect(1, message, "string")
	expect(2, expectedType, "string", "nil")
	while true do
		print(message .. ": ")
		local response = read(nil, nil, peripheral_extended)
		if response and peripheral.getType(response) then
			if expectedType and peripheral.getType(response) ~= expectedType then
				print("The peripheral is not of the expected type: " .. expectedType)
				return config.askPeripheral(message, expectedType)
			else
				return response
			end
		end
	end
end

--- Ask monitor
--- @param message string The message to display
--- @return string
function config.askMonitor(message)
	while true do
		print(message .. ": ")
		local response = read(nil, nil, peripheral_extended)
		if response and peripheral.getType(response) then
			if peripheral.getType(response) == "monitor" then
				local monitor = peripheral.wrap(response)
				if monitor.isColour() then
					monitor.setBackgroundColor(colors.red)
					monitor.clear()
					config.askYesNo("Is the correct monitor red?")
					monitor.setBackgroundColor(colors.black)
					monitor.clear()
					return response
				else
					print("The monitor does not support color")
					return config.askMonitor(message)
				end
			else
				print("The peripheral is not a monitor")
				return config.askMonitor(message)
			end
		end
	end
end

-- Helper function to ask for user input
function config.askInput(message, default)
	term.clear()
	term.setCursorPos(1, 1)
	print(message)
	if default ~= nil then
		write("Default: " .. tostring(default) .. " > ")
	else
		write("> ")
	end
	local input = read()
	if input == "" and default ~= nil then
		return default
	end
	return input
end

-- Helper function to ask for a numeric input
function config.askNumber(message, default)
	while true do
		local input = config.askInput(message, default)
		local num = tonumber(input)
		if num ~= nil then
			return num
		end
		print("Please enter a valid number.")
		sleep(1)
	end
end

-- Helper function to ask for an option from a list
function config.askOption(message, options)
	while true do
		term.clear()
		term.setCursorPos(1, 1)
		print(message)
		for i, option in ipairs(options) do
			print(i .. ") " .. option)
		end
		write("> ")
		local input = read()
		local num = tonumber(input)
		if num and num >= 1 and num <= #options then
			return options[num]
		elseif input ~= "" then
			-- Check if input matches option directly
			for _, option in ipairs(options) do
				if option:lower() == input:lower() then
					return option
				end
			end
		end
		print("Please enter a valid option.")
		sleep(1)
	end
end

-- Configure peripheral devices
function config.configPeripherals()
	local peripherals = peripheral.getNames()
	print("Available peripherals: " .. table.concat(peripherals, ", "))

	local carpet = config.askMonitor("Enter the carpet monitor name:")
	local ring = config.askMonitor("Enter the ring monitor name:")
	local redstone = config.askPeripheral("Enter the redstone input side:", nil)

	local ivManagers = {}
	local ivCount = config.askNumber("How many inventory managers?", 1)
	for i = 1, ivCount do
		ivManagers[i] = config.askPeripheral("Enter inventory manager " .. i .. " name:", "inventoryManager")
	end

	local ivmanBigger = config.askNumber("Base redstone signal strength:", 1)
	local modem = config.askPeripheral("Enter modem name:", "modem")

	return {
		carpet = carpet,
		ring = ring,
		redstone = redstone,
		ivmanagers = ivManagers,
		ivmanBigger = ivmanBigger,
		modem = modem,
	}
end

-- Configure reward multipliers
function config.configRewards()
	local numeric = config.askNumber("Reward multiplier for direct number bets:", 36)
	local dozen = config.askNumber("Reward multiplier for dozen bets:", 3)
	local binary = config.askNumber("Reward multiplier for binary bets:", 2)
	local colour = config.askNumber("Reward multiplier for color bets:", 2)

	return {
		numeric = numeric,
		dozen = dozen,
		binary = binary,
		colour = colour,
	}
end

-- Function to configure the table
function config.configTable()
	local toml = require("src.toml")

	term.clear()
	term.setCursorPos(1, 1)
	print("ToasterGen Spin Configuration Utility")
	print("====================================")

	-- Configure rewards and peripherals
	local rewards = config.configRewards()
	local devices = config.configPeripherals()

	-- Create the configuration
	local fullConfig = {
		version = "0.1.0",
		rewards = rewards,
		devices = devices,
	}

	-- Save the configuration
	local file = fs.open("/config.toml", "w")
	file.write(toml.encode(fullConfig))
	file.close()

	print("Configuration saved successfully!")
	print("Press any key to exit.")
	os.pullEvent("key")
end

return config
