--[[
    ToasterGen Spin

    Copyright (C) 2025 Clifton Toaster Reid <cliftontreid@duck.com>

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
]]

---@class Packet
---@field id number
---@field type string
---@field sender string
---@field recipient string

---@class ErrorPacket : Packet
---@field type "ERROR"
---@field message string The error message
---@field code number The error code

---@class HelloPacket : Packet
---@field type "HELLO"
---@field key string The public key of the client
---@field agent string The name of the client
---@field version string The version of the client
---@field name string The name of the client

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
---@field nonce number The nonce of the request
---@field request string The request to be made
---@field data any The data to be sent
---@field encrypted boolean Whether the data is encrypted
---@field encryptionMethod string The encryption method used
---@field iv string|nil initialization vector for encryption

---@class MethodicResponse : Packet
---@field type "RESPONSE"
---@field nonce number The nonce of the request
---@field response string The response to the request
---@field data any The data to be sent
---@field encrypted boolean Whether the data is encrypted
---@field encryptionMethod string The encryption method used
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
        id = os.epoch("utc"),
        sender = client.id,
        recipient = client.server,
        type = "HELLO",
        key = generateRandomString(32),
        agent = "ClientAgent",
        version = "1.0",
        name = "ClientName"
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



return {
    init = init
}
