--[[
    ToasterGen Spin

    Copyright (C) 2025 Clifton Toaster Reid <cliftontreid@duck.com>

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
]]

local completion = require "cc.completion"

--- Asks the user for a yes or no response
---@param message string The message to display
---@return boolean
local function askYesNo(message)
    local options = { "yes", "no" }
    while true do
        write(message .. " [Y/N]: ")
        local response = string.lower(read(nil, nil, function(text) return completion.choice(text, options) end))
        if response == "yes" or response == "y" then
            return true
        elseif response == "no" or response == "n" then
            return false
        end
    end
end

--- Asks the user to chose from a list of options
--- @param message string The message to display
--- @param options string[] The list of options to choose from
--- @return string
--- @return number
local function askOption(message, options)
    while true do
        print(message)
        for i, option in ipairs(options) do
            print(i .. "? " .. option)
        end

        write("Enter the number of your choice: ")
        local res = read(nil, nil, function(text) return completion.choice(text, options) end)

        -- Find the option index
        for i, option in ipairs(options) do
            if option == res then
                return option, i
            end
        end
        -- If the option is not found, try again

        print("Invalid option, please try again : " .. res)
        return askOption(message, options)
    end
end

--- Asks the user for a number
--- @param message string The message to display
--- @return number
local function askNumber(message)
    while true do
        print(message .. ": ")
        local response = tonumber(read())
        if response then
            return response
        end
    end
end

--- Asks the user for a peripheral
--- @param message string The message to display
--- @return string
local function askPeripheral(message)
    while true do
        print(message .. ": ")
        local response = read()
        if response and peripheral.getType(response) then
            return response
        end
    end
end

--- Ask monitor
--- @param message string The message to display
--- @return string
local function askMonitor(message)
    while true do
        print(message .. ": ")
        local response = read()
        if response and peripheral.getType(response) then
            if peripheral.getType(response) == "monitor" then
                local monitor = peripheral.wrap(response)
                if monitor.isColour() then
                    monitor.setBackgroundColor(colors.red)
                    monitor.clear()
                    askYesNo("Is the correct monitor red?")
                    monitor.setBackgroundColor(colors.black)
                    monitor.clear()
                    return response
                else
                    print("The monitor does not support color")
                    return askMonitor(message)
                end
            else
                print("The peripheral is not a monitor")
                return askMonitor(message)
            end
        end
    end
end

local function configTable()
    ---@type Config
    local config = {
        devices = {
            ring = askMonitor("Please enter the name of the Ring peripheral"),
            carpet = askMonitor("Please enter the name of the Carpet peripheral"),
            chatBox = askPeripheral("Please enter the name of the Chat Box peripheral"),
            playerDetector = askPeripheral("Please enter the name of the Player Detector peripheral")
        },
        rewards = {
            numeric = askNumber("Please enter the reward for a numeric bet"),
            dozen = askNumber("Please enter the reward for a dozen bet"),
            binary = askNumber("Please enter the reward for a binary bet"),
            colour = askNumber("Please enter the reward for a colour bet")
        },
        version = "0.1.0"
    }

    -- save the config
    local toml = require("src.toml")

    local file = fs.open("/config.toml", "w")
    file.write(toml.encode(config))
    file.close()
end

return {
    askYesNo = askYesNo,
    askOption = askOption,
    askNumber = askNumber,
    askPeripheral = askPeripheral,
    askMonitor = askMonitor,
    configTable = configTable
}
