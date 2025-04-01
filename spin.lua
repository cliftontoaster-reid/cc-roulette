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

---@class Reward
---@field numeric number The number with which to multiply the bet to get the payout
---@field dozen number The number with which to multiply the bet for winning the 1st 12, 2nd 12, and 3rd 12 options
---@field binary number The number with which to multiply the bet for winning the 1-18, 19-36, EVEN, and ODD options
---@field colour number The number with which to multiply the bet for winning the RED and BLACK options

---@class DeviceConfig
---@field carpet string The device that is used as carpet
---@field ring string The device that is used as ring
---@field chatBox string The device that is used as chat box
---@field playerDetector string The device that is used as player detector
---@field modem string The device that is used as modem

---@class ClientConfig
---@field version string The version of the config file schema using Semantic Versioning
---@field rewards Reward The rewards that can be given to the player

local toml = require("src.toml")

---@type ClientConfig
local config

---@return ClientConfig
local function loadConfig()
    local file = fs.open("/config.toml", "r")
    local config = toml.parse(file.readAll())

    file.close()
    return config
end

local function defaultConfig()
    ---@type ClientConfig
    local c = {
        version = "0.1.0",
        rewards = {
            numeric = 2,
            dozen = 1.75,
            binary = 1.35,
            colour = 1.35
        },
        devices = {
            carpet = "monitor_0",
            ring = "monitor_1",
            chatBox = "chatBox",
            playerDetector = "playerDetector"
        }
    }

    return c
end

local function saveConfig(config)
    local file = fs.open("/config.toml", "w")
    file.write(toml.encode(config))
    file.close()
end

local function isConfig()
    return fs.exists("config.toml")
end

--- Write the bets and the winning number to a file
---@param nbr number The winning number
---@param bets Bet[] The bets that have been placed
local function emergencyWrite(nbr, bets)
    -- write all bets to a json file '/bets.json' and the winning number to '/win'

    local file = fs.open("/bets.json", "w")
    file.write(textutils.serialize(bets))
    file.close()
    file = fs.open("/win", "w")
    file.write(textutils.serialize(nbr))
    file.close()
end

--- Finds the amount of coins a player has based on the Inventory Manager's index
---@param idx number The index/color of the player/Inventory Manager
local function getUserBallance(idx)

end

---@param bet Bet The bet to check
---@param nbr number The winning number
local function getPayout(bet, nbr)
    -- handle numeric bets
    if bet.number <= 36 and bet.number >= 0 then
        if bet.number == nbr then
            return bet.amount * config.rewards.numeric
        end
    end

    -- handle dozen bets
    if bet.number == 51 then
        if nbr >= 1 and nbr <= 12 then
            return bet.amount * config.rewards.dozen
        end
    end
    if bet.number == 52 then
        if nbr >= 13 and nbr <= 24 then
            return bet.amount * config.rewards.dozen
        end
    end
    if bet.number == 53 then
        if nbr >= 25 and nbr <= 36 then
            return bet.amount * config.rewards.dozen
        end
    end

    -- handle binary bets, 54 55 58 59
    if bet.number == 54 then -- 1 to 18
        if nbr >= 1 and nbr <= 18 then
            return bet.amount * config.rewards.binary
        end
    end
    if bet.number == 55 or bet.number == 56 then -- even / red
        if nbr % 2 == 0 then
            return bet.amount * config.rewards.binary
        end
    end
    if bet.number == 58 or bet.number == 57 then -- odd / black
        if nbr % 2 == 1 then
            return bet.amount * config.rewards.binary
        end
    end
    if bet.number == 59 then -- 19 to 36
        if nbr >= 19 and nbr <= 36 then
            return bet.amount * config.rewards.binary
        end
    end

    return nil
end

local function mainLoop()
    while true do
        local rEvent = { os.pullEventRaw() }
        local carpet = require("src.carpet")
        local ring = require("src.ring")
        local chat = require("src.chat")
        local Logger = require("src.log")
        local mod = require("src.modem")

        ring.init(config.devices.ring)
        chat.init(config.devices.chatBox, config.devices.playerDetector)
        carpet.init(config.devices.carpet)

        --- New coin
        if rEvent[1] == "redstone" then
            chat.handleCoin(rEvent[1])

            --- New chat message
        elseif rEvent[1] == "chat" then
            local chatEvent = {
                type = rEvent[1],
                username = rEvent[2],
                message = rEvent[3],
                uuid = rEvent[4],
                isHidden = rEvent[5]
            }
            chat.handleChatEvent(chatEvent)

            --- New monitor touch
        elseif rEvent[1] == "monitor_touch" then
            if rEvent[2] == config.devices.carpet then
                local bet = chat.getBet()
                if bet == nil then
                    Logger.error("No bet found")
                    return
                end

                local number = carpet.findClickedNumber(rEvent[3], rEvent[4])
                if number == nil then
                    Logger.error("No number found")
                    return
                end


                Logger.info("Bet added successfully")
            elseif config.devices.ring then
                local min, max = 150, 200
                local nbr = ring.launchBall(math.random(min, max))
                local bets = carpet.getBets()

                for _, b in ipairs(bets) do
                    local payout = getPayout(b, nbr)

                    if payout then
                        Logger.info("Payout for bet: " .. payout)
                        if mod.sendWin(b.player, b, payout) == 200 then
                            Logger.info("Payout sent to server")
                            chat.sendMessageToPlayer("You won " .. payout .. " coins!", b.player)
                        else
                            Logger.error("Error sending payout to server")
                        end
                    else
                        Logger.info("No payout for bet")
                    end
                end
            end
        end
    end
end

local function main()
    if not isConfig() then
        saveConfig(defaultConfig())
        error("No config file found, a default one has been created", 0)
        error("Please edit the config file to your liking", 0)
        return
    end


    config = loadConfig()
    mainLoop()
end

main()
