--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

-- Modified 2026-10-31 (kora): outbound HTTP is opt-in. Unless the convar
-- `ox:versionCheck` is true this is a no-op that never calls PerformHttpRequest,
-- whatever the consumer's own gate (e.g. `inventory:versioncheck`) says.
local versionCheckNoticed = false

function lib.versionCheck(repository)
    if GetConvar('ox:versionCheck', 'false') ~= 'true' then
        if not versionCheckNoticed and GetConvar('ox:printlevel', 'info') == 'debug' then
            versionCheckNoticed = true
            print('ox_lib: lib.versionCheck is disabled (set ox:versionCheck true to enable)')
        end

        return
    end

    local resource = GetInvokingResource() or GetCurrentResourceName()

    local currentVersion = GetResourceMetadata(resource, 'version', 0)

    if currentVersion then
        currentVersion = currentVersion:match('%d+%.%d+%.%d+')
    end

    if not currentVersion then return print(("^1Unable to determine current resource version for '%s' ^0"):format(resource)) end

    SetTimeout(1000, function()
        PerformHttpRequest(('https://api.github.com/repos/%s/releases/latest'):format(repository), function(status, response)
            if status ~= 200 then return end

            response = json.decode(response)
            if response.prerelease then return end

            local latestVersion = response.tag_name:match('%d+%.%d+%.%d+')
            if not latestVersion or latestVersion == currentVersion then return end

            local cv = { string.strsplit('.', currentVersion) }
            local lv = { string.strsplit('.', latestVersion) }

            for i = 1, #cv do
                local current, minimum = tonumber(cv[i]), tonumber(lv[i])

                if current ~= minimum then
                    if current < minimum then
                        return print(('^3An update is available for %s (current version: %s)\r\n%s^0'):format(resource, currentVersion, response.html_url))
                    else
                        break
                    end
                end
            end
        end, 'GET')
    end)
end
