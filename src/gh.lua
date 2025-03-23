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

local gh = {}

--- @class ReactionRollup
--- @field url string The API URL of the reactions. Format: uri
--- @field total_count integer The total number of reactions.
--- @field ['+1'] integer The number of thumbs up reactions.
--- @field ['-1'] integer The number of thumbs down reactions.
--- @field laugh integer The number of laugh reactions.
--- @field confused integer The number of confused reactions.
--- @field heart integer The number of heart reactions.
--- @field hooray integer The number of hooray reactions.
--- @field eyes integer The number of eyes reactions.
--- @field rocket integer The number of rocket reactions.

--- @class ReleaseAsset
--- @description Data related to a release.
--- @field url string The API URL of the asset. Format: uri
--- @field browser_download_url string The browser download URL of the asset. Format: uri
--- @field id integer The ID of the asset.
--- @field node_id string The node ID of the asset.
--- @field name string The file name of the asset. Example: "Team Environment"
--- @field label string|nil The label of the asset.
--- @field state string State of the release asset. Enum: "uploaded", "open"
--- @field content_type string The content type of the asset.
--- @field size integer The size of the asset in bytes.
--- @field download_count integer The number of times the asset has been downloaded.
--- @field created_at string The date and time the asset was created. Format: date-time
--- @field updated_at string The date and time the asset was updated. Format: date-time
--- @field uploader SimpleUser|nil The user who uploaded the asset.

--- @class SimpleUser
--- @description A GitHub user.
--- @field name string|nil The name of the user.
--- @field email string|nil The email of the user.
--- @field login string The login username of the user. Example: "octocat"
--- @field id integer The ID of the user. Format: int64. Example: 1
--- @field node_id string The node ID of the user. Example: "MDQ6VXNlcjE="
--- @field avatar_url string The avatar URL of the user. Format: uri. Example: "https://github.com/images/error/octocat_happy.gif"
--- @field gravatar_id string|nil The gravatar ID of the user. Example: "41d064eb2195891e12d0413f63227ea7"
--- @field url string The API URL of the user. Format: uri. Example: "https://api.github.com/users/octocat"
--- @field html_url string The HTML URL of the user. Format: uri. Example: "https://github.com/octocat"
--- @field followers_url string The API URL for the user's followers. Format: uri. Example: "https://api.github.com/users/octocat/followers"
--- @field following_url string The API URL for the users the user is following. Example: "https://api.github.com/users/octocat/following{/other_user}"
--- @field gists_url string The API URL for the user's gists. Example: "https://api.github.com/users/octocat/gists{/gist_id}"
--- @field starred_url string The API URL for the repos the user has starred. Example: "https://api.github.com/users/octocat/starred{/owner}{/repo}"
--- @field subscriptions_url string The API URL for the user's subscriptions. Format: uri. Example: "https://api.github.com/users/octocat/subscriptions"
--- @field organizations_url string The API URL for the user's organizations. Format: uri. Example: "https://api.github.com/users/octocat/orgs"
--- @field repos_url string The API URL for the user's public repos. Format: uri. Example: "https://api.github.com/users/octocat/repos"
--- @field events_url string The API URL for the user's events. Example: "https://api.github.com/users/octocat/events{/privacy}"
--- @field received_events_url string The API URL for the events the user has received. Format: uri. Example: "https://api.github.com/users/octocat/received_events"
--- @field type string The type of the user. Example: "User"
--- @field site_admin boolean Whether the user is a site administrator.
--- @field starred_at string Example: "\"2020-07-09T00:17:55Z\""
--- @field user_view_type string Example: "public"

--- @class Release
--- @description A release.
--- @field url string The API URL of the release.
--- @field html_url string The HTML URL of the release.
--- @field assets_url string The API URL for the release's assets.
--- @field upload_url string The upload URL for the release's assets.
--- @field tarball_url string|nil The tarball URL of the release.
--- @field zipball_url string|nil The zipball URL of the release.
--- @field id integer The ID of the release.
--- @field node_id string The node ID of the release.
--- @field tag_name string The name of the tag. Example: "v1.0.0"
--- @field target_commitish string Specifies the commitish value that determines where the Git tag is created from. Example: "master"
--- @field name string|nil The name of the release.
--- @field body string|nil The body of the release notes.
--- @field draft boolean true to create a draft (unpublished) release, false to create a published one. Example: false
--- @field prerelease boolean Whether to identify the release as a prerelease or a full release. Example: false
--- @field created_at string The date and time the release was created. Format: date-time
--- @field published_at string|nil The date and time the release was published. Format: date-time
--- @field author SimpleUser The author of the release.
--- @field assets ReleaseAsset[] array of release assets.
--- @field body_html string The HTML version of the release body.
--- @field body_text string The plain text version of the release body.
--- @field mentions_count integer The number of mentions in the release body.
--- @field discussion_url string The URL of the release discussion.
--- @field reactions ReactionRollup The reactions to the release.

--- Fetches the releases for a given GitHub repository.
--- @param githubUser string The GitHub username of the repository owner.
--- @param githubRepo string The GitHub repository name.
--- @param logger Logger The logger to use for output.
--- @return Release[]|nil The releases for the repository, or nil if an error occurred.
function gh.getReleases(githubUser, githubRepo, logger)
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

return gh
