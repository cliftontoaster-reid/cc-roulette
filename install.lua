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
    LOG_FILE = "/tools/roulette-install.log",
    LOG_LEVEL = "INFO", -- DEBUG, INFO, WARNING, ERROR
    ARCHIVE_FILES = {
        "LibDeflate.lua", "ar.lua", "archive.lua", "arlib.lua",
        "gzip.lua", "muxzcat.lua", "tar.lua", "unxz.lua"
    }
}

-- Logging system
local Logger = {
    LEVELS = {
        DEBUG = { priority = 1, color = colors.gray },
        INFO = { priority = 2, color = colors.lightGray },
        WARNING = { priority = 3, color = colors.yellow },
        ERROR = { priority = 4, color = colors.red },
        SUCCESS = { priority = 2, color = colors.lime }
    }
}

function Logger.getTimestamp()
    return os.date("[%Y-%m-%d %H:%M:%S]")
end

function Logger.debug(message)
    Logger.log("DEBUG", message)
end

function Logger.info(message)
    Logger.log("INFO", message)
end

function Logger.warning(message)
    Logger.log("WARNING", message)
end

function Logger.error(message)
    Logger.log("ERROR", message)
end

function Logger.success(message)
    Logger.log("SUCCESS", message)
end

-- Update the main log function to align output
function Logger.log(level, message)
    local logConfig = Logger.LEVELS[level]
    local currentLevel = Logger.LEVELS[CONFIG.LOG_LEVEL].priority

    if logConfig.priority >= currentLevel then
        local oldColour = term.getTextColour()

        -- Use colour only if supported
        if term.isColor() then
            term.setTextColour(logConfig.color)
        end

        -- Format with fixed width for level to ensure alignment
        local timestamp = Logger.getTimestamp()
        local levelPadded = string.format("%-8s", "[" .. level .. "]")
        local logMessage = timestamp .. " " .. levelPadded .. " " .. message

        print(logMessage)

        -- Write to log file if enabled
        if CONFIG.LOG_FILE then
            local file = fs.open(CONFIG.LOG_FILE, fs.exists(CONFIG.LOG_FILE) and "a" or "w")
            if file then
                file.writeLine(logMessage)
                file.close()
            end
        end

        term.setTextColour(oldColour)
    end
end

-- Utility functions
local function printHeader(text)
    local oldColor = term.getTextColor()
    term.setTextColor(colors.cyan)
    print("======================================")
    print(text)
    print("======================================")
    term.setTextColor(oldColor)
    Logger.debug("Header displayed: " .. text)
end

local function printFooter()
    local oldColor = term.getTextColor()
    term.setTextColor(colors.cyan)
    print("======================================")
    term.setTextColor(oldColor)
    Logger.debug("Footer displayed")
end

local function ensureDirectory(path)
    if not fs.exists(path) then
        fs.makeDir(path)
        Logger.debug("Created directory: " .. path)
        return true
    end
    Logger.debug("Directory already exists: " .. path)
    return false
end

local function downloadFile(url, path, binary)
    Logger.debug("Downloading file from " .. url .. " to " .. path)
    local response = http.get(url, nil, binary)
    if not response then
        Logger.error("Failed to download from " .. url)
        return false, "Failed to download from " .. url
    end

    local data = response.readAll()
    response.close()

    local file = fs.open(path, "wb")
    file.write(data)
    file.close()

    Logger.debug("Successfully downloaded file to " .. path)
    return true
end

-- GitHub API functions
local function getReleases()
    local url = string.format(
        "https://api.github.com/repos/%s/%s/releases",
        CONFIG.GITHUB_USER,
        CONFIG.GITHUB_REPO
    )

    Logger.info("Fetching releases from GitHub API...")
    local response = http.get(url)
    if not response then
        Logger.error("Failed to fetch releases from GitHub API")
        return nil
    end

    local data = response.readAll()
    response.close()
    Logger.debug("Received " .. #data .. " bytes of release data")
    return textutils.unserializeJSON(data)
end

local function downloadCCArchive()
    if fs.exists(CONFIG.ARCHIVE_DIR) then
        Logger.info("CC-Archive already exists at " .. CONFIG.ARCHIVE_DIR)
        return true
    end

    Logger.info("Downloading CC-Archive...")
    ensureDirectory(CONFIG.TOOLS_DIR)
    ensureDirectory(CONFIG.ARCHIVE_DIR)

    local baseUrl = "https://github.com/MCJack123/CC-Archive/raw/refs/heads/master/"
    local totalFiles = #CONFIG.ARCHIVE_FILES

    for i, file in ipairs(CONFIG.ARCHIVE_FILES) do
        Logger.info(string.format("[%d/%d] Downloading %s", i, totalFiles, file))
        local success, error = downloadFile(baseUrl .. file, CONFIG.ARCHIVE_DIR .. "/" .. file)
        if not success then
            Logger.error("Failed to download " .. file .. ": " .. error)
            error(error)
        end
        os.sleep(0.1) -- Prevent rate limiting
    end

    Logger.success("Successfully downloaded all CC-Archive components")
    return true
end

local function downloadAndExtractRelease(release)
    Logger.info("Starting download of release " .. release.tag_name)
    ensureDirectory(CONFIG.TEMP_DIR)

    local tempFile = CONFIG.TEMP_DIR .. "/release.tar.gz"
    if fs.exists(tempFile) then
        Logger.debug("Removing existing temp file: " .. tempFile)
        fs.delete(tempFile)
    end

    Logger.info("Downloading release archive...")
    local success, err = downloadFile(release.tarball_url, tempFile, true)
    if not success then
        Logger.error("Failed to download release archive: " .. err)
        error(err)
    end

    Logger.info("Extracting release files...")
    ensureDirectory(CONFIG.ROULETTE_DIR)

    Logger.debug("Running tar command to extract files")
    shell.run(CONFIG.ARCHIVE_DIR .. "/tar.lua", "xzf", tempFile, "-C", CONFIG.ROULETTE_DIR)

    -- Handle nested directory
    local files = fs.list(CONFIG.ROULETTE_DIR)
    if #files == 1 and fs.isDir(CONFIG.ROULETTE_DIR .. "/" .. files[1]) then
        local folder = files[1]
        local folderPath = CONFIG.ROULETTE_DIR .. "/" .. folder

        Logger.info("Organizing extracted files from nested directory: " .. folder)
        local fileCount = 0
        for _, file in ipairs(fs.list(folderPath)) do
            fs.move(folderPath .. "/" .. file, CONFIG.ROULETTE_DIR .. "/" .. file)
            fileCount = fileCount + 1
        end

        Logger.debug("Moved " .. fileCount .. " files to target directory")
        Logger.debug("Removing temporary directory: " .. folderPath)
        fs.delete(folderPath)
    end

    Logger.success("Release extraction completed successfully")
    return true
end

local function displayReleaseSummary(release)
    printHeader("Release Summary for " .. CONFIG.GITHUB_REPO)

    Logger.info("Version: " .. release.tag_name)
    Logger.info("Name: " .. (release.name or "Unnamed"))
    Logger.info("Published: " .. (release.published_at or release.created_at or "Unknown"))

    local status = release.draft and "Draft" or (release.prerelease and "Pre-release" or "Stable")
    Logger.info("Status: " .. status)
    Logger.info("Assets: " .. #release.assets)

    if release.body then
        Logger.info("Description:")
        local shortDesc = string.sub(release.body, 1, 100)
        if #release.body > 100 then shortDesc = shortDesc .. "..." end
        Logger.info(shortDesc)
    end

    printFooter()
end

-- Main execution
local function main()
    Logger.info("Starting installation of " .. CONFIG.GITHUB_REPO .. "...")

    Logger.debug("Configuration settings:")
    for key, value in pairs(CONFIG) do
        if type(value) ~= "table" then
            Logger.debug("  " .. key .. " = " .. tostring(value))
        end
    end

    local releases = getReleases()

    if not releases or #releases == 0 then
        Logger.error("No releases found for repository")
        return
    end

    local latest = releases[1]
    Logger.info("Found latest release: " .. latest.tag_name)

    displayReleaseSummary(latest)

    downloadCCArchive()
    downloadAndExtractRelease(latest)

    printHeader("Installation complete")
    Logger.success("Installation of " .. CONFIG.GITHUB_REPO .. " completed successfully")
end

-- Run the program
main()
