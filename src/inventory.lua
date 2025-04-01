--[[
    ToasterGen Spin

    Copyright (C) 2025 Clifton Toaster Reid <cliftontreid@duck.com>

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
]]

---@class IvMnager
---@field addItemToPlayer fun(direction: "top"|"bottom"|"left"|"right"|"front"|"back", item: table): number
---@field removeItemFromPlayer fun(direction: "top"|"bottom"|"left"|"right"|"front"|"back", item: table): number
---@field getArmor fun(): table
---@field getOwner fun(): string
---@field isPlayerEquipped fun(): boolean
---@field isWearing fun(slot: number): boolean
---@field getItemInHand fun(): table
---@field getItemInOffHand fun(): table
---@field getFreeSlot fun(): number
---@field isSpaceAvailable fun(): boolean
---@field getEmptySpace fun(): number

local money = "minecraft:emerald"

---@type table<number, IvMnager>
local invManagers = {}

local inv = {}

---Gets the amount of money (emeralds) a player has in their off-hand
---@param idx number The player index in invManagers
---@return number|nil The count of money items, or nil if player not found, no item in off-hand, or item is not money
local function getMoneyInPlayer(idx)
    local player = invManagers[idx]
    if not player then
        return nil
    end

    local success, item = pcall(function() return player:getItemInOffHand() end)
    if not success or not item then
        return nil
    end
    if item.name ~= money then
        return nil
    end
    return item.count
end

---Removes a specified amount of money from a player
---@param idx number The player index in invManagers
---@param amount number The amount of money to take from the player
---@return number|nil The amount taken if successful, nil if player not found or has insufficient funds
local function takeMoneyFromPlayer(idx, amount)
    local player = invManagers[idx]
    if not player then
        return nil
    end

    local count = getMoneyInPlayer(idx)
    if not count or count < amount then
        return nil
    end

    local success, result = pcall(function()
        return player.removeItemFromPlayer("bottom", {
            name = money,
            count = amount
        })
    end)

    if not success then
        return nil
    end
    return amount
end

---Adds a specified amount of money to a player
---@param idx number The player index in invManagers
---@param amount number The amount of money to add to the player
---@return number|nil The amount added if successful, nil if player not found or adding fails
local function addMoneyToPlayer(idx, amount)
    local player = invManagers[idx]
    if not player then
        return nil
    end

    local success, res = pcall(function()
        return player.addItemToPlayer("bottom", {
            name = money,
            count = amount
        })
    end)

    if not success then
        return nil
    end

    if res ~= amount then
        -- take back the money given
        local takeBackSuccess = pcall(function()
            player.removeItemFromPlayer("bottom", {
                name = money,
                count = res
            })
        end)
        -- Even if takeBackSuccess fails, we still return nil
        return nil
    end

    return amount
end

---Gets a player's ownership information
---@param idx number The player index in invManagers
---@return string|nil The player owner identifier, or nil if player not found
local function getPlayer(idx)
    local player = invManagers[idx]
    if not player then
        return nil
    end

    local success, own = pcall(function() return player.getOwner() end)
    if not success or not own then
        return nil
    end
    return own
end

inv.getMoneyInPlayer = getMoneyInPlayer
inv.takeMoneyFromPlayer = takeMoneyFromPlayer
inv.addMoneyToPlayer = addMoneyToPlayer
inv.getPlayer = getPlayer

return inv
