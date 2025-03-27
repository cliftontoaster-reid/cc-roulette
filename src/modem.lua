--[[
    ToasterGen Spin

    Copyright (C) 2025 Clifton Toaster Reid <cliftontreid@duck.com>

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
]]

---@class Packet
---@field type string
---@field sender string
---@field recipient string
---@field nonce number The nonce of the request

---@class ErrorPacket : Packet
---@field type "ERROR"
---@field message string The error message
---@field code number The error code

---@class HelloPacket : Packet
---@field type "HELLO"
---@field key string The public key of the client
---@field agent string The name of the client
---@field version string The version of the client

---@class PingPacket : Packet
---@field type "PING"
---@field time number The time the packet was sent

---@class PongPacket : Packet
---@field type "PONG"
---@field time number The time the packet was sent

---@class AcknPacket : Packet
---@field type "ACKN"
---@field key string The public key of the server
---@field agent string The name of the server
---@field version string The version of the server

---@class MethodicPacket : Packet
---@field type "METHODIC"
---@field method "GET" | "POST" | "PUT" | "DELETE" The method of the request
---@field request string The request to be made
---@field data any The data to be sent
---@field encrypted boolean Whether the data is encrypted
---@field encryptionMethod string|nil The encryption method used
---@field iv string|nil initialization vector for encryption

---@class MethodicResponse : Packet
---@field type "RESPONSE"
---@field code number The response code
---@field data any The data to be sent
---@field encrypted boolean Whether the data is encrypted
---@field encryptionMethod string|nil The encryption method used
---@field iv string|nil initialization vector for encryption

---@class Client
---@field id string The id of the client
---@field version string The version of the client
---@field agent string The agent of the client
---@field key string The token of the client
---@field server string The server the client is connected to
---@field serverKey string The public key of the server
---@field serverAgent string The agent of the server
---@field serverVersion string The version of the server


local function generateRandomString(length)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = ""

    math.randomseed(os.time())

    for i = 1, length do
        local charIndex = math.random(1, #chars)
        result = result .. string.sub(chars, charIndex, charIndex)
    end

    return result
end


---@type Client
local client = {
    id = generateRandomString(32),
    version = "0.1.0",
    agent = "pinknet",
    key = generateRandomString(32),
    server = "HEAD",
    serverKey = "",
    serverAgent = "",
    serverVersion = ""
}

local modem = nil
local carpet = require("src.carpet")

local function init(modemName)
    modem = peripheral.wrap(modemName)
    if modem == nil then
        error("Modem not found", 0)
    end

    if not fs.exists("/.var/key") then
        local key = generateRandomString(32)
        local file = fs.open("/.var/key", "w")
        file.write(key)
        file.close()
        print("No key was found, a new key has been generated at '/.var/key', make sure to upload it to the server." ..
            key)
        print("We suggest you use a drive to transfer the key to the server.")
        error("PINKNET_KEYMISSING", 0)
    end

    modem.open(1)
    modem.open(5)

    ---@type HelloPacket
    local pck = {
        nonce = os.epoch("utc"),

        sender = client.id,
        recipient = client.server,
        type = "HELLO",
        key = generateRandomString(32),
        agent = "Spin",
        version = "0.1.0",
    }

    modem.transmit(1, 1, pck)
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        if message.type then
            if message.type == "ACKN" and message.recipient == client.id then
                print("Acknowledgment received from recipient: " .. message.recipient)

                client.serverAgent = message.agent
                client.serverKey = message.key
                client.serverVersion = message.version
                print("Server information updated: Agent - " ..
                    client.serverAgent .. ", Key - " .. client.serverKey .. ", Version - " .. client.serverVersion)
                break
            end
            if message.type == "ERROR" and message.recipient == client.id then
                print("Error received from recipient: " .. message.recipient)
                print("Error message: " .. message.message)
                return false
            end
        end
    end

    print("Connection established with server")
    return true
end

local function newNonce()
    return os.epoch("utc")
end

--- Creates a new methodic request
---
---@param method "GET" | "POST" | "PUT" | "DELETE" The method of the request
---@param request string The request to be made
---@param data any The data to be sent
---@param encryptionMethod string|nil The encryption method used
---@param iv string|nil initialization vector for encryption
local function newMethodic(method, request, data, encryptionMethod, iv)
    if not modem then
        error("Modem not initialized", 0)
    end

    local nonce = newNonce()

    ---@type MethodicPacket
    local packet = {
        type = "METHODIC",
        sender = client.id,
        recipient = client.server,
        nonce = nonce,
        method = method,
        request = request,
        data = data,
        encrypted = encryptionMethod ~= nil,
        encryptionMethod = encryptionMethod,
        iv = iv
    }

    modem.transmit(5, 5, packet)
    return nonce
end

local function sendPacketSync(packet)
    if not modem then
        error("Modem not initialized", 0)
    end
    modem.transmit(5, 1, packet)

    while true do
        local rEvent = { os.pullEventRaw() }
        if rEvent[1] == "modem_message" then
            local event, side, channel, replyChannel, message, distance = table.unpack(rEvent)
            return message, channel, replyChannel
        end
    end
end

local function sendPacketAsync(packet)
    if not modem then
        error("Modem not initialized", 0)
    end
    modem.transmit(5, 1, packet)

    return packet.nonce
end

--- Pings another modem and waits for a response
---
---@param target string The target to ping
---@param timeout number The timeout for the ping
---@return boolean Whether the target responded
---@return number The time it took for the target to respond
local function ping(target, timeout)
    if not modem then
        error("Modem not initialized", 0)
    end
    local startTime = os.epoch("utc")

    ---@type PingPacket
    local pck = {
        type = "PING",
        sender = client.id,
        recipient = target,
        time = startTime,

        nonce = newNonce()
    }

    modem.transmit(5, 1, pck)

    while true do
        local rEvent = { os.pullEventRaw() }

        if os.epoch("utc") - startTime > timeout then
            return false, 0
        end
        if rEvent[1] == "modem_message" then
            local event, side, channel, replyChannel, message, distance = table.unpack(rEvent)

            if message.type == "PONG" and message.recipient == client.id then
                return true, message.time - startTime
            end
        end
    end
end

---@param bet Bet
---@param number number
---@param config Reward
---@return MethodicResponse | nil
---@return number | nil
---@return number | nil
local function sendWin(bet, number, config)
    local won, nbr = carpet.checkWin(bet, number)
    if won then
        local reward = config[nbr]

        if reward == nil then
            error("No reward found for number " .. nbr, 0)
        end

        local pck = newMethodic("POST", "/win", {
            bet = bet,
            number = number,
            reward = reward
        })
        return sendPacketSync(pck)
    else
        return nil, nil, nil
    end
end

--- Listens for incoming messages
---
---@param secure boolean Whether to use secure mode
---@param callback fun(message: MethodicPacket): MethodicResponse|ErrorPacket The callback to call when a message is received
local function listen(secure, callback)
    if not modem then
        error("Modem not initialized", 0)
    end

    local key = nil
    if not fs.exists("/.var/key") then
        key = generateRandomString(32)
        local file = fs.open("/.var/key", "w")
        file.write(key)
        file.close()
    else
        local file = fs.open("/.var/key", "r")
        key = file.readAll()
        file.close()
    end

    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

        if message.type == "METHODIC" then
            if callback then
                local success, err = pcall(callback, message)
                if not success then
                    print("Error in callback: " .. tostring(err))
                end
            end
        elseif message.type == "PING" then
            ---@type PongPacket
            local pck = {
                type = "PONG",
                sender = client.id,
                recipient = message.sender,
                time = os.epoch("utc"),
                nonce = message.nonce
            }

            modem.transmit(channel, replyChannel, pck)
        elseif message.type == "HELLO" then
            ---@type AcknPacket
            local pck = {
                nonce = message.nonce,
                sender = client.id,
                recipient = message.sender,
                type = "ACKN",
                key = key,
                agent = "Stator",
                version = "0.1.0",
            }

            if secure then
                local i = 1
                while fs.exists("/.var/keys/" .. i) do
                    local file = fs.open("/.var/keys/" .. i, "r")
                    local key = file.readAll()
                    file.close()

                    if key == message.key then
                        modem.transmit(channel, replyChannel, pck)
                        break
                    end

                    i = i + 1
                end

                local ErrorPacket = {
                    type = "ERROR",
                    sender = client.id,
                    recipient = message.sender,
                    nonce = message.nonce,
                    message = "Unauthorized",
                    code = 403
                }
                modem.transmit(channel, replyChannel, ErrorPacket)
            else
                modem.transmit(channel, replyChannel, pck)
            end
        end
    end
end

return {
    init = init,
    ping = ping,
    newNonce = newNonce,

    newMethodic = newMethodic,
    sendPacketSync = sendPacketSync,
    sendPacketAsync = sendPacketAsync,

    sendWin = sendWin,

    listen = listen
}
