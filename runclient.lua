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

local files = {
    "install.lua",
    "tools/config.lua",
    "src/log.lua",
    "src/toml.lua",
    "src/semver.lua",
}
local gh_repo = "https://raw.githubusercontent.com/cliftontoaster-reid/cc-roulette/main/"
-- download everything inside /.var/
local function downloadFiles()
    for _, file in ipairs(files) do
        local url = gh_repo .. file
        -- check if the file exists
        if not fs.exists("/.var/" .. file) then
            print("Downloading: " .. file)
            local response = http.get(url)
            if response then
                local content = response.readAll()
                -- create the directory if it doesn't exist
                if not fs.exists("/.var") then
                    fs.makeDir("/.var")
                    fs.makeDir("/.var/tools")
                    fs.makeDir("/.var/src")
                end
                local f = fs.open("/.var/" .. file, "w")
                f.write(content)
                f.close()
                print("Downloaded: " .. file)
            else
                print("Failed to download: " .. file)
            end
        end
    end
end

downloadFiles()

shell.setDir("/.var")
if shell.run("install") then
    print("Installation completed successfully.")
else
    error("Installation failed.")
end

shell.setDir("/")
shell.run("tools/roulette/spin.lua")
