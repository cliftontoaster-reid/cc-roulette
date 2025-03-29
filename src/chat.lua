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

local msg
local players

local function init(charBox, playerDetector)
    msg = peripheral.wrap(charBox)
    if msg == nil then
        error("ChatBox not found", 0)
    end
    players = peripheral.wrap(playerDetector)
    if players == nil then
        error("PlayerDetector not found", 0)
    end
end

---@class Player
---@field name string
---@field uuid string
---@field colour number

---@type Player[]
local players = {}

local function addPlayer(player)
    -- Check if player already exists
    for _, p in ipairs(players) do
        if p.uuid == player.uuid then
            return
        end
    end

    -- Define a set of available colors
    local candidateColors = { 1, 2, 3, 4, 5, 6, 7, 8 }
    local usedColors = {}

    -- Collect colors that are already in use
    for _, p in ipairs(players) do
        if p.colour then
            usedColors[p.colour] = true
        end
    end

    -- Build list of colors not yet assigned
    local available = {}
    for _, color in ipairs(candidateColors) do
        if not usedColors[color] then
            table.insert(available, color)
        end
    end

    -- If no unique color available, return an error
    if #available == 0 then
        error("No available colors remaining", 0)
    end

    -- Select a random color from the available ones
    local randomIndex = math.random(#available)
    player.colour = available[randomIndex]

    table.insert(players, player)
end

local function removePlayer(player)
    for i, p in ipairs(players) do
        if p.uuid == player.uuid then
            table.remove(players, i)
            break
        end
    end
end

local function getPlayer(uuid)
    for _, p in ipairs(players) do
        if p.uuid == uuid then
            return p
        end
    end
    return nil
end

local function getPlayers()
    return players
end

local function clearPlayers()
    players = {}
end

---@class tmpBet
---@field amount number
---@field player string | nil
---@field uuid string | nil

---@type tmpBet
local tmpBet = {
    amount = 0,
    player = nil,
}

local PLAYERZONE = 5
local COMMANDS = {
    "register",
    "redeem"
}

local function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

---@class ChatEvent
---@field type string The type of event
---@field username string The username of the player who sent the message
---@field uuid string The UUID of the player who sent the message
---@field message string The message sent by the player
---@field isHidden boolean Whether the message is hidden

---Handles chat events
---@param event ChatEvent The chat event to handle
local function handleChatEvent(event)
    if event.type ~= "chat" then
        return
    end
    if not event.isHidden or has_value(COMMANDS, event.message) then
        print("Received invalid chat event")
        return
    end
    -- Check if the player is
    local around = players.getPlayersInCubic(PLAYERZONE, PLAYERZONE, PLAYERZONE)
    local isAround = false
    for _, player in ipairs(around) do
        if player.uuid == event.uuid then
            isAround = true
            break
        end
    end
    if not isAround then
        error("Player '" .. event.username .. "' not in range", 0)
        return
    end

    if event.message == "register" then
        if tmpBet.player ~= nil then
            if tmpBet.player == event.username then
                msg.sendMessageToPlayer("You are already registered, you may proceed to place a bet", event.username)
            elseif tmpBet.player ~= event.username then
                msg.sendMessageToPlayer("A player is currently registered, please wait for them to place a bet",
                    event.username)
            end
            return
        end
        tmpBet.player = event.username
        tmpBet.uuid = event.uuid
        msg.sendMessageToPlayer("You have been registered, you may now place a bet", event.username)
    elseif event.message == "redeem" then
        msg.sendMessageToPlayer("Please visit the chute to redeem your coins", event.username)
    end
end

---@param event string
local function handleCoin(event)
    if event ~= "coin" then
        return
    end
    tmpBet.amount = tmpBet.amount + 1
    if tmpBet.player == nil then
        msg.sendMessage(
            "No player registered, please use '$register' before placing a bet, there are currently " .. tmpBet.amount ..
            " coins without an owner")
        return -1
    end
    msg.sendMessageToPlayer("Coin received, a total of " .. tmpBet.amount .. " coins are now in your account",
        tmpBet.player)
    return 0
end

local function getBet()
    if tmpBet.player == nil then
        msg.sendMessage("No player is currently registered, please use '$register' before placing a bet, there are " ..
            tmpBet.amount .. " coins without an owner")
        return nil
    end
    local bet = tmpBet
    tmpBet = {
        amount = 0,
        player = nil,
    }
    return bet
end

local msgFuncs = {}

msgFuncs.handleChatEvent = handleChatEvent
msgFuncs.handleCoin = handleCoin
msgFuncs.getBet = getBet
msgFuncs.addPlayer = addPlayer
msgFuncs.removePlayer = removePlayer
msgFuncs.getPlayer = getPlayer
msgFuncs.getPlayers = getPlayers
msgFuncs.clearPlayers = clearPlayers
msgFuncs.addPlayer = addPlayer
msgFuncs.removePlayer = removePlayer
msgFuncs.init = init

--- Sends a message to all players
---@param message string The message to send
---@return nil
msgFuncs.sendMessage = function(message)
    if msg then
        msg.sendMessage(message)
    else
        error("ChatBox not initialized", 0)
    end
end

--- Sends a message to a player
---@param message string The message to send
---@param player string The player to send the message to
---@return nil
msgFuncs.sendMessageToPlayer = function(message, player)
    if msg then
        msg.sendMessageToPlayer(message, player)
    else
        error("ChatBox not initialized", 0)
    end
end

return msgFuncs
