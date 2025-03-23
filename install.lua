--[[
    ToasterGen Spin

    Copyright (C) 2025 Clifton Toaster Reid <cliftontreid@duck.com>

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
]]

-- Configuration
local CONFIG = {
    GITHUB_USER = "cliftontoaster-reid",
    GITHUB_REPO = "cc-roulette",
    TOOLS_DIR = "/tools",
    ROULETTE_DIR = "/tools/roulette",
    ARCHIVE_DIR = "/tools/cc-archive",
    TEMP_DIR = "/tmp",
    ARCHIVE_FILES = {
        "LibDeflate.lua", "ar.lua", "archive.lua", "arlib.lua",
        "gzip.lua", "muxzcat.lua", "tar.lua", "unxz.lua"
    }
}

-- Utility functions
local function printHeader(text)
    print("======================================")
    print(text)
    print("======================================")
end

local function printFooter()
    print("======================================")
end

local function ensureDirectory(path)
    if not fs.exists(path) then
        fs.makeDir(path)
        return true
    end
    return false
end

local function downloadFile(url, path, binary)
    local response = http.get(url, nil, binary)
    if not response then
        return false, "Failed to download from " .. url
    end

    local data = response.readAll()
    response.close()

    local file = fs.open(path, "wb")
    file.write(data)
    file.close()

    return true
end

-- GitHub API functions
local function getReleases()
    local url = string.format(
        "https://api.github.com/repos/%s/%s/releases",
        CONFIG.GITHUB_USER,
        CONFIG.GITHUB_REPO
    )

    local response = http.get(url)
    if not response then return nil end

    local data = response.readAll()
    response.close()
    return textutils.unserializeJSON(data)
end

local function downloadCCArchive()
    if fs.exists(CONFIG.ARCHIVE_DIR) then return true end

    print("Downloading cc-archive...")
    ensureDirectory(CONFIG.TOOLS_DIR)
    ensureDirectory(CONFIG.ARCHIVE_DIR)

    local baseUrl = "https://github.com/MCJack123/CC-Archive/raw/refs/heads/master/"

    for _, file in ipairs(CONFIG.ARCHIVE_FILES) do
        print("Downloading " .. file)
        local success, error = downloadFile(baseUrl .. file, CONFIG.ARCHIVE_DIR .. "/" .. file)
        if not success then
            error(error)
        end
        os.sleep(0.1) -- Prevent rate limiting
    end

    print("Downloaded cc-archive.")
    return true
end

local function downloadAndExtractRelease(release)
    print("Downloading release...")
    ensureDirectory(CONFIG.TEMP_DIR)

    local tempFile = CONFIG.TEMP_DIR .. "/release.tar.gz"
    if fs.exists(tempFile) then fs.delete(tempFile) end

    local success, eor = downloadFile(release.tarball_url, tempFile, true)
    if not success then error(eor) end

    print("Extracting release...")
    ensureDirectory(CONFIG.ROULETTE_DIR)

    shell.run(CONFIG.ARCHIVE_DIR .. "/tar.lua", "xzf", tempFile, "-C", CONFIG.ROULETTE_DIR)

    -- Handle nested directory
    local files = fs.list(CONFIG.ROULETTE_DIR)
    if #files == 1 and fs.isDir(CONFIG.ROULETTE_DIR .. "/" .. files[1]) then
        local folder = files[1]
        local folderPath = CONFIG.ROULETTE_DIR .. "/" .. folder

        for _, file in ipairs(fs.list(folderPath)) do
            fs.move(folderPath .. "/" .. file, CONFIG.ROULETTE_DIR .. "/" .. file)
        end

        fs.delete(folderPath)
    end

    return true
end

local function displayReleaseSummary(release)
    printHeader("Release Summary for " .. CONFIG.GITHUB_REPO)

    print("Version: " .. release.tag_name)
    print("Name: " .. (release.name or "Unnamed"))
    print("Published: " .. (release.published_at or release.created_at or "Unknown"))
    print("Status: " .. (release.draft and "Draft" or
        release.prerelease and "Pre-release" or "Stable"))
    print("Assets: " .. #release.assets)

    if release.body then
        print("Description:")
        local shortDesc = string.sub(release.body, 1, 100)
        if #release.body > 100 then shortDesc = shortDesc .. "..." end
        print(shortDesc)
    end

    printFooter()
end

-- Main execution
local function main()
    local releases = getReleases()

    if not releases or #releases == 0 then
        print("No releases found.")
        return
    end

    local latest = releases[1]
    displayReleaseSummary(latest)

    downloadCCArchive()
    downloadAndExtractRelease(latest)

    printHeader("Installation complete.")
end

-- Run the program
main()
