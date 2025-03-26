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

---@class Config
---@field version string The version of the config file schema using Semantic Versioning
---@field rewards Reward The rewards that can be given to the player

local toml = require("src.toml")

local config

---@return Config
local function loadConfig()
    local file = fs.open("/config.toml", "r")
    local config = toml.parse(file.readAll())

    file.close()
    return config
end

local function defaultConfig()
    ---@type Config
    local config = {
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
end

local function saveConfig(config)
    local file = fs.open("/config.toml", "w")
    file.write(toml.encode(config))
    file.close()
end

local function isConfig()
    return fs.exists("config.toml")
end

local function mainLoop()
    while true do
        local rEvent = { os.pullEventRaw() }
        local carpet = require("src.carpet")
        local ring = require("src.ring")
        local chat = require("src.chat")
        local Logger = require("src.log")

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
            local bet = chat.getBet()
            if bet == nil then
                Logger.error("No bet found")
                return
            end
            if rEvent[2] == config.devices.carpet then
                local number = carpet.findClickedNumber(rEvent[3], rEvent[4])
                if number == nil then
                    Logger.error("No number found")
                    return
                end

                Logger.info("Bet added successfully")
            elseif config.devices.ring then
                local min, max = 150, 200
                local nbr = ring.launchBall(math.random(min, max))

                -- go througj all the bets, and check if the number is in the bet
                -- if it is, then add the reward to the player by multiplying the bet by the configured reward
                -- send a message and send a request to the server to update the player's balance
                for _, bet in pairs(chat.getBets()) do
                    if bet.number == nbr then
                        local reward = config.rewards.numeric * bet.amount
                        chat.sendMessageToPlayer(bet.player, "You won " .. reward .. " cogs!")
                        chat.updatePlayerBalance(bet.player, reward)
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
