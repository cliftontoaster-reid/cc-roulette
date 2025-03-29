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
---@field redstone "top"|"bottom"|"left"|"right"|"front"|"back" The side that is used for redstone

---@class ServerConfig
---@field version string The version of the config file schema using Semantic Versioning
---@field devices ServerDevice The devices that are used in the server

---@class PlayerData
---@field name string
---@field uuid string
---@field balance number
---@field bets number[]

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
            redstone = "back"
        }
    }

    return config
end

local function saveConfig()
    local file = fs.open(configPath, "w")
    file.write(toml.encode(config))
    file.close()
end



---@param req MethodicPacket
local function handleRequests(req)
    if req.method == "POST" then
        if req.request == "/win" then
            ---@class WinRequest
            ---@field bet Bet
            ---@field number number
            ---@field reward number

            ---@type WinRequest
            local reqData = req.data

            if db.existsQuery("players", { uuid = reqData.bet.uuid }) then
                ---@type PlayerData
                local player = db.getQuery("players", { uuid = reqData.bet.uuid })
                player.balance = player.balance + reqData.reward
                db.update("players", player.uuid, player)
            else
                -- create new player

                ---@type PlayerData
                local newPlayer = {
                    name = reqData.bet.name,
                    uuid = reqData.bet.uuid,
                    balance = reqData.reward,
                    bets = {}
                }
                local suc, err = db.create("players", newPlayer.uuid, newPlayer)
                if not suc then
                    ---@type ErrorPacket
                    local res = {
                        code = 500,
                        message = err or "Internal Server Error",
                        nonce = req.nonce,
                        recipient = req.sender,
                        sender = "HEAD",
                        type = "ERROR"
                    }
                    return res
                end
            end
        end
    end
end

local function isAround(uuid, radius)
    local around = peripheral.call("playerDetector", "getPlayersInCubic", radius[1], radius[2], radius[3])
    for _, player in ipairs(around) do
        if player.uuid == uuid then
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

local function getPlayer(uuid)
    if db.existsQuery("players", { uuid = uuid }) then
        ---@type PlayerData
        local player = db.getQuery("players", { uuid = uuid })
        return player
    end

    return 0
end

local function handleEvents(event)
    if event[1] == "chat" then
        local chatEvent = {
            type = event[1],
            username = event[2],
            message = event[3],
            uuid = event[4],
            isHidden = event[5]
        }
        if not chatEvent.isHidden or not isAround(chatEvent.uuid, { 4, 10, 4 }) then
            return;
        end

        -- remove the first character
        local cmd = chatEvent.message:sub(2)
        if cmd == "redeem" then
            local spurs = getSpursAmount()
            local data = getPlayer(chatEvent.uuid)

            if data.balance > spurs then
                chat.sendMessageToPlayer("We are sorry, but we cannot process your request at this time.",
                    chatEvent.username, "Spin")
                return
            end
            if data.balance == 0 then
                chat.sendMessageToPlayer("You have no balance to redeem.", chatEvent.username, "Spin")
                return
            end

            -- send a one tick pulse to the redstone for every coin in balance
            chat.sendMessageToPlayer("Redeeming your balance of " .. data.balance .. " spurs.", chatEvent.username,
                "Spin")
            for _ = 1, data.balance do
                peripheral.call(config.devices.redstone, "emit", "back", 15)
                os.sleep(0.1)
                peripheral.call(config.devices.redstone, "emit", "back", 0)
                os.sleep(0.1)
            end
            chat.sendMessageToPlayer("Redeemed " .. data.balance .. " spurs.", chatEvent.username, "Spin")

            -- update player balance
            data.balance = 0
            db.update("players", chatEvent.uuid, data)
            chat.sendMessageToPlayer("Your balance has been reset, have a wonderful day.", chatEvent.username, "Spin")
        end
    end
end

local function init()
    if fs.exists(configPath) then
        loadConfig()
    else
        config = defaultConfig()
        saveConfig()
        error("Config file not found. Created default config file at " .. configPath)
    end

    modem.init(config.devices.modem)
    modem.listen(false, handleRequests, handleEvents)

    chat = peripheral.wrap(config.devices.chatBox)
end

init()
