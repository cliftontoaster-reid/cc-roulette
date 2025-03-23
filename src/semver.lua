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

--- Semantic Versioning (SemVer) Module with Extended Utility Functions.
--- Implements parsing, comparing, converting, and additional utility functions for semver strings.
--- For full details on semantic versioning, see: https://semver.org

local semver = {}

--- @class SemverVersion
--- Represents a semantic version.
--- @field major number The major version.
--- @field minor number The minor version.
--- @field patch number The patch version.
--- @field prerelease string|nil Optional pre-release identifier.
--- @field build string|nil Optional build metadata.

--- Parses a semantic version string into a SemverVersion object.
--- The accepted format is "MAJOR.MINOR.PATCH", with optional pre-release and build metadata.
--- Examples:
---   "1.2.3"           => major=1, minor=2, patch=3
---   "1.2.3-alpha"     => prerelease="alpha"
---   "1.2.3-alpha+001" => prerelease="alpha", build="001"
--- @param version_str string The semantic version string to parse.
--- @return SemverVersion|nil The parsed version table, or nil if the format is invalid.
--- @return string|nil Error message if parsing fails.
function semver.parse(version_str)
    if type(version_str) ~= "string" then
        return nil, "Version must be a string"
    end

    -- Split by "+" to extract build metadata
    local version_part, build
    local plus_pos = version_str:find("%+")
    if plus_pos then
        version_part = version_str:sub(1, plus_pos - 1)
        build = version_str:sub(plus_pos + 1)

        if #build == 0 then
            return nil, "Build metadata cannot be empty"
        end
    else
        version_part = version_str
    end

    -- Split by "-" to extract prerelease
    local main_version, prerelease
    local hyphen_pos = version_part:find("%-")
    if hyphen_pos then
        main_version = version_part:sub(1, hyphen_pos - 1)
        prerelease = version_part:sub(hyphen_pos + 1)

        if #prerelease == 0 then
            return nil, "Prerelease identifier cannot be empty"
        end
    else
        main_version = version_part
    end

    -- Parse major.minor.patch
    local parts = {}
    for part in main_version:gmatch("[^%.]+") do
        table.insert(parts, part)
    end

    if #parts ~= 3 then
        return nil, "Version must have exactly three numeric parts: major.minor.patch"
    end

    -- Validate and convert numeric parts
    local major, minor, patch
    for i, part in ipairs(parts) do
        -- Check for non-digits
        if part:match("[^0-9]") then
            return nil, "Version parts must contain only digits"
        end

        -- Check for leading zeros (except when value is 0)
        if #part > 1 and part:sub(1, 1) == "0" then
            return nil, "Version parts cannot have leading zeros"
        end

        local num = tonumber(part)
        if not num then
            return nil, "Failed to convert version part to number"
        end

        if i == 1 then
            major = num
        elseif i == 2 then
            minor = num
        else
            patch = num
        end
    end

    -- Validate prerelease format if present
    if prerelease then
        for identifier in prerelease:gmatch("[^%.]+") do
            if #identifier == 0 then
                return nil, "Prerelease identifiers cannot be empty"
            end

            -- Must contain only alphanumerics and hyphens
            if identifier:match("[^0-9A-Za-z%-]") then
                return nil, "Prerelease identifiers must contain only alphanumerics and hyphens"
            end

            -- Numeric identifiers cannot have leading zeros
            local num = tonumber(identifier)
            if num and #identifier > 1 and identifier:sub(1, 1) == "0" then
                return nil, "Numeric prerelease identifiers cannot have leading zeros"
            end
        end
    end

    -- Validate build metadata format if present
    if build then
        for identifier in build:gmatch("[^%.]+") do
            if #identifier == 0 then
                return nil, "Build metadata identifiers cannot be empty"
            end

            -- Must contain only alphanumerics and hyphens
            if identifier:match("[^0-9A-Za-z%-]") then
                return nil, "Build metadata identifiers must contain only alphanumerics and hyphens"
            end
        end
    end

    return {
        major = major,
        minor = minor,
        patch = patch,
        prerelease = prerelease,
        build = build
    }
end

--- Compares two SemverVersion objects.
--- Comparison follows semver precedence rules:
--- 1. Compare major, minor, then patch numbers.
--- 2. A version without a prerelease field has higher precedence than one with a prerelease.
--- 3. If both have prerelease values, compare them by splitting into dot-separated identifiers.
--- @param v1 SemverVersion The first version.
--- @param v2 SemverVersion The second version.
--- @return number Returns 1 if v1 > v2, -1 if v1 < v2, or 0 if both are equal.
function semver.compare(v1, v2)
    if v1.major ~= v2.major then
        return v1.major > v2.major and 1 or -1
    end
    if v1.minor ~= v2.minor then
        return v1.minor > v2.minor and 1 or -1
    end
    if v1.patch ~= v2.patch then
        return v1.patch > v2.patch and 1 or -1
    end

    -- When numeric parts arINFOe equal, handle prerelease.
    if v1.prerelease == v2.prerelease then
        return 0
    elseif v1.prerelease == nil then
        return 1 -- a version without prerelease is higher
    elseif v2.prerelease == nil then
        return -1
    else
        -- Split prerelease string by dot.
        local function split(str)
            local t = {}
            for part in string.gmatch(str, "([^%.]+)") do
                table.insert(t, part)
            end
            return t
        end

        local pre1 = split(v1.prerelease)
        local pre2 = split(v2.prerelease)
        local len = math.max(#pre1, #pre2)
        for i = 1, len do
            local a = pre1[i]
            local b = pre2[i]
            if a == nil then
                return -1
            elseif b == nil then
                return 1
            else
                local na = tonumber(a)
                local nb = tonumber(b)
                if na and nb then
                    if na ~= nb then
                        return na > nb and 1 or -1
                    end
                elseif na then
                    -- Numeric identifiers have lower precedence than non-numeric.
                    return -1
                elseif nb then
                    return 1
                else
                    if a ~= b then
                        return a > b and 1 or -1
                    end
                end
            end
        end
        return 0
    end
end

--- Converts a SemverVersion object back to its string representation.
--- @param version SemverVersion The version object.
--- @return string The semantic version string.
function semver.toString(version)
    local str = string.format("%d.%d.%d", version.major, version.minor, version.patch)
    if version.prerelease then
        str = str .. "-" .. version.prerelease
    end
    if version.build then
        str = str .. "+" .. version.build
    end
    return str
end

-- Utility functions for comparing parsed SemverVersion objects

--- Checks if two SemverVersion objects are equal.
--- @param v1 SemverVersion The first version.
--- @param v2 SemverVersion The second version.
--- @return boolean True if equal, false otherwise.
function semver.eq(v1, v2)
    return semver.compare(v1, v2) == 0
end

--- Checks if the first SemverVersion object is greater than the second.
--- @param v1 SemverVersion The first version.
--- @param v2 SemverVersion The second version.
--- @return boolean True if v1 > v2, false otherwise.
function semver.gt(v1, v2)
    return semver.compare(v1, v2) == 1
end

--- Checks if the first SemverVersion object is less than the second.
--- @param v1 SemverVersion The first version.
--- @param v2 SemverVersion The second version.
--- @return boolean True if v1 < v2, false otherwise.
function semver.lt(v1, v2)
    return semver.compare(v1, v2) == -1
end

--- Checks if the first SemverVersion object is greater than or equal to the second.
--- @param v1 SemverVersion The first version.
--- @param v2 SemverVersion The second version.
--- @return boolean True if v1 >= v2, false otherwise.
function semver.ge(v1, v2)
    local cmp = semver.compare(v1, v2)
    return cmp == 1 or cmp == 0
end

--- Checks if the first SemverVersion object is less than or equal to the second.
--- @param v1 SemverVersion The first version.
--- @param v2 SemverVersion The second version.
--- @return boolean True if v1 <= v2, false otherwise.
function semver.le(v1, v2)
    local cmp = semver.compare(v1, v2)
    return cmp == -1 or cmp == 0
end

-- Utility functions for comparing version strings directly

--- Compares two semantic version strings.
--- @param version1 string A semantic version string.
--- @param version2 string A semantic version string.
--- @return number|nil Returns 1 if version1 > version2, -1 if version1 < version2, 0 if equal,
--- or nil with an error message if a version string is invalid.
--- @return string|nil Error message if a version string is invalid.
function semver.compare_strings(version1, version2)
    local v1, err1 = semver.parse(version1)
    if not v1 then return nil, "Invalid version1: " .. err1 end
    local v2, err2 = semver.parse(version2)
    if not v2 then return nil, "Invalid version2: " .. err2 end
    return semver.compare(v1, v2)
end

--- Checks if two semantic version strings are equal.
--- @param version1 string A semantic version string.
--- @param version2 string A semantic version string.
--- @return boolean|nil True if equal, false if not, or nil with an error message if a version string is invalid.
--- @return string|nil Error message if a version string is invalid.
function semver.eq_str(version1, version2)
    local cmp, err = semver.compare_strings(version1, version2)
    if cmp == nil then return nil, err end
    return cmp == 0
end

--- Checks if the first semantic version string is greater than the second.
--- @param version1 string A semantic version string.
--- @param version2 string A semantic version string.
--- @return boolean|nil True if version1 > version2, false if not, or nil with an error message if a version string is invalid.
--- @return string|nil Error message if a version string is invalid.
function semver.gt_str(version1, version2)
    local cmp, err = semver.compare_strings(version1, version2)
    if cmp == nil then return nil, err end
    return cmp == 1
end

--- Checks if the first semantic version string is less than the second.
--- @param version1 string A semantic version string.
--- @param version2 string A semantic version string.
--- @return boolean|nil True if version1 < version2, false if not, or nil with an error message if a version string is invalid.
--- @return string|nil Error message if a version string is invalid.
function semver.lt_str(version1, version2)
    local cmp, err = semver.compare_strings(version1, version2)
    if cmp == nil then return nil, err end
    return cmp == -1
end

--- Sorts an array of semantic version strings.
--- @param versions table Array of semantic version strings.
--- @return table|nil Sorted array of semantic version strings, or nil with an error message if any version is invalid.
--- @return string|nil Error message if a version string is invalid.
function semver.sort(versions)
    local parsed_versions = {}
    for i, ver_str in ipairs(versions) do
        local v, err = semver.parse(ver_str)
        if not v then return nil, "Invalid version at index " .. i .. ": " .. err end
        parsed_versions[i] = { original = ver_str, parsed = v }
    end

    table.sort(parsed_versions, function(a, b)
        return semver.compare(a.parsed, b.parsed) < 0
    end)

    local sorted_versions = {}
    for i, entry in ipairs(parsed_versions) do
        sorted_versions[i] = entry.original
    end
    return sorted_versions
end

return semver
