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
---@field modem string The device that is used as modem
---@field redstone string The device that is used as redstone
---@field ivmanagers table<number, string> The devices that are used as inventory managers
---@field ivmanBigger number The streigth of the signal for the lowest inventory manager

---@class DebugConfig
---@field loki string | nil The URL of the Loki server to send logs to
---@field tempo string | nil The URL of the Tempo server to send traces to

---@type number | nil
local LokiTimer = nil
local LokiSleepyTime = 5
---@type number | nil
local TempoTimer = nil
local TempoSleepyTime = 2

---@class ClientConfig
---@field version string The version of the config file schema using Semantic Versioning
---@field rewards Reward The rewards that can be given to the player
---@field devices DeviceConfig The devices that are used in the game
---@field debug DebugConfig The debug configuration

local toml = require("src.toml")

---@type ClientConfig
local config
local currentBetter = -1

local ucolors = {
    -- Cannot be red, black or green
    colors.orange,
    colors.yellow,
    colors.pink,
    colors.cyan,
    colors.blue,
    colors.purple,
    colors.white,
    colors.lime,
}

---@return ClientConfig
local function loadConfig()
    local file = fs.open("/config.toml", "r")
    local cfg = toml.parse(file.readAll())

    file.close()
    return cfg
end

local function defaultConfig()
    ---@type ClientConfig
    local c = {
        version = "0.1.0",
        rewards = {
            numeric = 2,
            dozen = 1.75,
            binary = 1.35,
            colour = 1.35,
        },
        devices = {
            carpet = "monitor_0",
            ring = "monitor_1",
            redstone = "back",
            ivmanagers = { "playerDetector_1" },
            modem = "top",
            ivmanBigger = 1,
        },
        debug = {
            loki = nil,
        },
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
    -- Load modules once outside the loop
    local carpet = require("src.carpet")
    local ring = require("src.ring")
    local Logger = require("src.log")
    local Tracer = require("src.trace")
    local iv = require("src.inventory")

    if config.debug then
        if config.debug.loki then
            Logger.setLoki(config.debug.loki)
        end
        if config.debug.tempo then
            Tracer.setTempo(config.debug.tempo)
        end
    end

    -- Initialize devices
    iv.init(config.devices.ivmanagers)
    ring.init(config.devices.ring)
    carpet.init(config.devices.carpet)

    -- Handle redstone signal events
    local function handleRedstoneEvent()
        local redStreingth = redstone.getAnalogInput(config.devices.redstone)
        local id = redStreingth - config.devices.ivmanBigger
        if id < 0 then
            Logger.error("Redstone signal too low")
            return
        end
        -- Store the player id in currentBetter
        currentBetter = id
        Logger.info("Player " .. id .. " clicked on the button")
    end

    -- Handle carpet monitor touch events
    local function handleCarpetTouch(x, y)
        if currentBetter == -1 then
            Logger.error("No player detected")
            return
        end

        local ballance = iv.getMoneyInPlayer(currentBetter)
        if ballance == nil or ballance <= 0 then
            Logger.error("Player " .. currentBetter .. " has no money")
            Logger.debug("Player is " .. (iv.getPlayer(currentBetter) or ""))
            return
        end

        local nbr = carpet.findClickedNumber(x, y)
        if nbr == nil then
            Logger.error("No number clicked")
            return
        end

        local res = iv.takeMoneyFromPlayer(currentBetter, 1)
        if res == nil then
            Logger.error("Error taking money from player " .. currentBetter)
            return
        end

        local player = iv.getPlayer(currentBetter)
        carpet.addBet(1, ucolors[currentBetter + 1], player or "", nbr)
        Logger.info("Bet added successfully")
        os.sleep(0.2)
    end

    -- Handle ring monitor touch events
    local function handleRingTouch()
        local min, max = 150, 200
        local nbr = ring.launchBall(math.random(min, max))
        local bets = carpet.getBets()

        Logger.info("Running through " .. #bets .. " bets")
        for _, b in ipairs(bets) do
            Logger.debug("Checking bet for player " ..
                b.player .. " on number " .. b.number .. " with color " .. b.color .. " and amount " .. b.amount)
            local payout = getPayout(b, nbr)

            if payout then
                Logger.info("Payout for bet: " .. payout)
                local idx = iv.findPlayer(b.player)
                if idx == nil then
                    Logger.error("Player " .. b.player .. " not found for payout")
                else
                    local res = iv.addMoneyToPlayer(idx - 1, payout)
                    if res == nil then
                        Logger.error("Failed to give money to player " .. b.player)
                        emergencyWrite(nbr, bets)
                    else
                        Logger.info("Money added to player " .. b.player)
                    end
                end
                Logger.info("Payout processed for player " .. b.player)
            else
                Logger.info("No payout for bet")
            end
        end
        carpet.resetBets()
        carpet.update()
        Logger.info("Bets reset successfully")
    end

    -- Handle monitor touch events
    local function handleMonitorTouch(monitorName, x, y)
        if monitorName == config.devices.carpet then
            handleCarpetTouch(x, y)
        elseif monitorName == config.devices.ring then
            handleRingTouch()
        end
    end

    LokiTimer = os.startTimer(LokiSleepyTime)
    TempoTimer = os.startTimer(TempoSleepyTime)

    -- Main event loop
    while true do
        local rEvent = { os.pullEventRaw() }

        if rEvent[1] == "redstone" then
            handleRedstoneEvent()
        elseif rEvent[1] == "monitor_touch" then
            handleMonitorTouch(rEvent[2], rEvent[3], rEvent[4])
        elseif rEvent[1] == "terminate" then
            Logger.info("Terminating program")
            error("Program terminated by user", 0)
        elseif rEvent[1] == "timer" then
            if rEvent[2] == LokiTimer then
                Logger.sendLoki()
                LokiTimer = os.startTimer(LokiSleepyTime)
            elseif rEvent[2] == TempoTimer then
                Tracer.sendTempo()
                TempoTimer = os.startTimer(TempoSleepyTime)
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
