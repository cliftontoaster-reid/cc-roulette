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

local config
local db = require("src.database")
local modem = require("src.modem")

db.init("/.db/")

---@return ServerConfig
local function loadConfig()
    local file = fs.open(configPath, "r")
    local config = toml.parse(file.readAll())

    file.close()
    return config
end

local function defaultConfig()
    ---@type ServerConfig
    local config = {
        version = "0.1.0",
        devices = {
            modem = "top"
        }
    }

    return config
end

local function saveConfig()
    local file = fs.open(configPath, "w")
    file.write(toml.stringify(config))
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

local function init()
    if fs.exists(configPath) then
        config = loadConfig()
    else
        config = defaultConfig()
        saveConfig()
        error("Config file not found. Created default config file at " .. configPath)
    end

    modem.init(config.devices.modem)
    modem.listen(false, handleRequests)
end

init()
