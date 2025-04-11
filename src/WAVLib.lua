--[[
    CC-WAV-loader - Load any WAV file for use in ComputerCraft
    Repository: https://github.com/Kestin4Real/CC-WAV-loader
    Description: Load any WAV file for use in ComputerCraft
    Language: Lua (100%)

    Copyright (c) 2025 Kestin4Real.
    All rights reserved.

    Note: This code is provided without an explicit license. Use at your own discretion.
    If you plan to redistribute or modify this work, please give proper attribution to the original repository.
    For any formal permissions or licensing clarification, consider contacting the original author.
]]
--

---@class Audio
---@field channels integer Number of audio channels (1 = mono, 2 = stereo)
---@field frequency integer Sample rate in Hz (e.g., 44100)
---@field bytesPerSample integer Bytes per sample (1 = 8-bit, 2 = 16-bit)
---@field samples integer Total number of samples per channel
---@field lenght number Total duration in seconds
---@field channelData table<integer, integer[]> Array of channel data arrays (1-based index)

local api = {}

---@class AudioLoader
---@field file any The file handle being read
local AudioLoader = {}
AudioLoader.__index = AudioLoader

---Create a new AudioLoader instance
---@return AudioLoader
function AudioLoader.new()
    local self = setmetatable({}, AudioLoader)
    self.file = nil
    return self
end

---Reads bytes in big-endian format
---@param amount integer Number of bytes to read
---@return integer
function AudioLoader:ReadBytesBig(amount)
    local integer = 0
    for i = 1, amount do
        integer = bit.blshift(integer, 8) + self.file.read()
    end
    return integer
end

---Reads bytes in little-endian format
---@param amount integer Number of bytes to read
---@param signed? boolean Whether to interpret as signed integer (default false)
---@return integer
function AudioLoader:ReadBytesLittle(amount, signed)
    if signed == nil then
        signed = false
    end
    local integer = 0
    for i = 1, amount do
        local byte = self.file.read()
        integer = integer + bit.blshift(byte, 8 * (i - 1))
        if signed then
            if i == amount then
                local sign = bit.brshift(byte, 7) == 1
                if not sign then
                    return integer
                end
                integer = integer - bit.blshift(1, 7 + (8 * (i - 1)))
                integer = integer - (math.pow(256, amount) / 2)
            end
        end
    end
    return integer
end

---Reads bytes as hexadecimal string
---@param amount integer Number of bytes to read
---@return string
function AudioLoader:ReadBytesAsHex(amount)
    local hex = ""
    for i = 1, amount do
        hex = hex .. string.format("%02X", self.file.read())
    end
    return hex
end

---Parses the format chunk (fmt )
---@param audio Audio Audio object to populate
function AudioLoader:ParseFMTchunk(audio) --FMT subchunk parser
    if not (self:ReadBytesLittle(4) == 16) then
        print("File is in a incorrect format or corrupted 0x04")
        return
    end --Check for chunk size 16
    if not (self:ReadBytesAsHex(2) == "0100") then
        print("File is in a incorrect format or corrupted 0x05")
        return
    end                                             --Check WAVE type 0x01
    audio.channels = self:ReadBytesLittle(2)        --number of channels
    audio.frequency = self:ReadBytesLittle(4)       --sample frequency
    self:ReadBytesBig(4)                            --bytes/sec (Garbage Data)
    self:ReadBytesBig(2)                            --block alignment (Garbage Data)
    audio.bytesPerSample = self:ReadBytesLittle(2) / 8 --bits per sample
end

---Parses the data chunk (data)
---@param audio Audio Audio object to populate
function AudioLoader:ParseDATAchunk(audio) --DATA subchunk parser
    --size of the data chunk
    audio.samples = self:ReadBytesLittle(4) / audio.channels / audio.bytesPerSample
    audio.lenght = audio.samples / audio.frequency
    for s = 0, audio.samples - 1 do
        local sample = 0
        for c = 0, audio.channels - 1 do
            sample = sample + self:ReadBytesLittle(audio.bytesPerSample, audio.bytesPerSample > 1)
            if audio.bytesPerSample == 1 then
                sample = sample - 128
            end
        end
        audio[s] = math.floor(sample / audio.channels / math.max(256 * (audio.bytesPerSample - 1), 1))
    end
end

---Skips non-essential chunks
---@param audio Audio Audio object being parsed
function AudioLoader:ParseDUMMYchunk(audio) --Parser for non essential data
    self:ReadBytesLittle(self:ReadBytesLittle(4))
end

---Main loading function
---@param path string Path to WAV file
---@return Audio|nil Loaded audio object or nil on failure
function AudioLoader:Load(path)
    path = shell.resolve(path)
    if not fs.exists(path) then
        print("File does not exists")
        return
    end
    if fs.isDir(path) then
        print("File does not exists")
        return
    end
    self.file = fs.open(path, "rb")
    local audio = {}

    if not (self:ReadBytesAsHex(4) == "52494646") then
        print("File is in a incorrect format or corrupted 0x01")
        self.file.close()
        return
    end                  --Check header for RIFF
    self:ReadBytesLittle(4) -- size of file
    if not (self:ReadBytesAsHex(4) == "57415645") then
        print("File is in a incorrect format or corrupted 0x02")
        self.file.close()
        return
    end --Check WAVE header for WAVE

    local parsers = {}
    parsers["666D7420"] = function(audio)
        self:ParseFMTchunk(audio)
    end --FMT subchunk parser
    parsers["64617461"] = function(audio)
        self:ParseDATAchunk(audio)
    end --DATA subchunk parser

    while audio.lenght == nil do
        local subchunk = self:ReadBytesAsHex(4)
        if subchunk == nil then
            print("File is in a incorrect format or corrupted 0x03")
            self.file.close()
            return
        end
        local parser = parsers[subchunk]
        if parser == nil then
            self:ParseDUMMYchunk(audio)
        else
            parser(audio)
        end
    end
    self.file.close()

    return audio
end

-- Create the public API
function api.Load(path)
    local loader = AudioLoader.new()
    return loader:Load(path)
end

return api
