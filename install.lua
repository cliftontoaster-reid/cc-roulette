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
    LOG_LEVEL = "DEBUG", -- DEBUG, INFO, WARNING, ERROR
    ARCHIVE_FILES = {
        "LibDeflate.lua", "ar.lua", "archive.lua", "arlib.lua",
        "gzip.lua", "muxzcat.lua", "tar.lua", "unxz.lua"
    },
    VERSION_FILE = "/tools/roulette/version",
}

local Logger = require("src.log")
local semver = require("src.semver")

local args = { ... }
local forceDev = false
local forceDel = false
for i, arg in ipairs(args) do
    if arg == "--dev" then
        forceDev = true
    elseif arg == "--del" then
        forceDel = true
    end
end

--- Fetches the releases for a given GitHub repository.
--- @param githubUser string The GitHub username of the repository owner.
--- @param githubRepo string The GitHub repository name.
--- @param logger Logger The logger to use for output.
--- @return Release[]|nil The releases for the repository, or nil if an error occurred.
local function getReleases(githubUser, githubRepo, logger)
    local url = string.format("https://api.github.com/repos/%s/%s/releases", githubUser, githubRepo)
    logger.info("Fetching releases from GitHub API...")
    local response = http.get(url)
    if not response then
        logger.error("Failed to fetch releases from GitHub API")
        return nil
    end
    local data = response.readAll()
    response.close()
    logger.debug("Received " .. #data .. " bytes of release data")
    return textutils.unserializeJSON(data)
end

-- Update the main log function to align output
function Logger.log(level, message)
    local trimmedLevel = level:gsub("%s+$", "")
    local logConfig = Logger.LEVELS[trimmedLevel]
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
        local success, err = downloadFile(baseUrl .. file, CONFIG.ARCHIVE_DIR .. "/" .. file)
        if not success then
            Logger.error("Failed to download " .. file .. ": " .. error)
            error(err)
        end
        os.sleep(0.2) -- Prevent rate limiting
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
    if forceDel then
        Logger.info("Force deletion (--del) detected. Removing entire tools directory: " .. CONFIG.TOOLS_DIR)
        if fs.exists(CONFIG.TOOLS_DIR) then
            fs.delete(CONFIG.TOOLS_DIR)
            Logger.success("Successfully removed " .. CONFIG.TOOLS_DIR)
        else
            Logger.warning("No tools directory found at " .. CONFIG.TOOLS_DIR)
        end
    end

    local update = false

    Logger.info("Starting installation of " .. CONFIG.GITHUB_REPO .. "...")

    -- If the --dev flag is present, force install from the provided URL
    if (forceDev) then
        Logger.info("Force installation (--dev) detected. Forcing installation from dev release.")

        local latest = {
            tag_name = "vDEV",
            tarball_url = "https://github.com/cliftontoaster-reid/cc-roulette/archive/main.tar.gz"
        }

        if fs.exists(CONFIG.ROULETTE_DIR) then
            Logger.info("Removing existing installation due to --dev flag")
            fs.delete(CONFIG.ROULETTE_DIR)
        end

        downloadCCArchive()
        downloadAndExtractRelease(latest)

        printHeader("Installation complete")
        Logger.success("Installation (dev) of " .. CONFIG.GITHUB_REPO .. " completed successfully")

        local versionFile = fs.open(CONFIG.VERSION_FILE, "w")
        versionFile.writeLine(latest.tag_name:sub(2))
        versionFile.close()

        local config = require("tools.config")
        if config.askYesNo("Would you like to configure the program now?") then
            local dev = config.askOption("What device would you like to configure?", { "Table", "Server" })
            if dev == "Table" then
                config.configTable()
            elseif dev == "Server" then
                error("Server configuration not yet implemented, we apologize for the inconvenience")
            end
        end

        Logger.debug("Exiting the program (dev mode)...")
        return true
    end

    local releases = getReleases(CONFIG.GITHUB_USER, CONFIG.GITHUB_REPO, Logger)

    if not releases or #releases == 0 then
        Logger.error("No releases found for repository")
        return
    end

    local latest = releases[1]
    Logger.info("Found latest release: " .. latest.tag_name)

    displayReleaseSummary(latest)

    if fs.exists(CONFIG.ROULETTE_DIR) then
        update = true
        Logger.info("Existing installation found at " .. CONFIG.ROULETTE_DIR)

        local versionFile = fs.open(CONFIG.VERSION_FILE, "r")
        if versionFile then
            local currentVersion = versionFile.readLine()
            versionFile.close()

            local cVer = semver.parse(currentVersion)
            local lVer = semver.parse(latest.tag_name:sub(2))

            Logger.debug("Installed version: " .. currentVersion)
            Logger.debug("Latest version: " .. latest.tag_name)
            if not cVer or not lVer or semver.ge(cVer, lVer) then
                Logger.success("Installed version is up to date")
                return
            else
                Logger.info("Updating from version " .. currentVersion .. " to " .. latest.tag_name)
                fs.delete(CONFIG.ROULETTE_DIR)
            end
        else
            Logger.warning("Failed to read version file, continuing with installation")
            fs.delete(CONFIG.ROULETTE_DIR)
        end
    end

    downloadCCArchive()
    downloadAndExtractRelease(latest)

    printHeader("Installation complete")
    Logger.success("Installation of " .. CONFIG.GITHUB_REPO .. " completed successfully")

    local versionFile = fs.open(CONFIG.VERSION_FILE, "w")
    versionFile.writeLine(latest.tag_name:sub(2))
    versionFile.close()

    local config = require("tools.config")

    if not update then
        if config.askYesNo("Would you like to configure the program now?") then
            local dev = config.askOption("What device would you like to configure?", { "Table", "Server" })
            if dev == "Table" then
                config.configTable()
            elseif dev == "Server" then
                error("Server configuration not yet implemented, we apologize for the inconvenience")
            end
        end
    end

    Logger.debug("Exiting the program...")
    return true
end

-- Run the program
main()
