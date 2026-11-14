--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

-- Modified 2026-10-31 (kora): qbx_core and qbx_vehicles are satisfied by the
-- kora_core facade. The alias only rescues a check that upstream logic would
-- fail, and only while the alias target is started; messages are unchanged.
-- Disable with the convar `ox:dependencyAlias 0`.
local dependencyAliases = {
    qbx_core = 'kora_core',
    qbx_vehicles = 'kora_core',
}

local function checkDependency(resource, minimumVersion, printMessage)
	local currentVersion = GetResourceMetadata(resource, 'version', 0)
    currentVersion = currentVersion and currentVersion:match('%d+%.%d+%.%d+') or 'unknown'

	if currentVersion ~= minimumVersion then
		local cv = { string.strsplit('.', currentVersion) }
		local mv = { string.strsplit('.', minimumVersion) }
		local msg = ("^1%s requires version '%s' of '%s' (current version: %s)^0"):format(GetInvokingResource() or GetCurrentResourceName(), minimumVersion, resource, currentVersion)

		for i = 1, #cv do
            local current, minimum = tonumber(cv[i]), tonumber(mv[i])

            if current ~= minimum then
                if not current or current < minimum then
                    if printMessage then
                        return print(msg)
                    end

                    return false, msg
                else break end
            end
		end
	end

	return true
end

function lib.checkDependency(resource, minimumVersion, printMessage)
    local ok, msg = checkDependency(resource, minimumVersion, false)

    if ok == false then
        local alias = dependencyAliases[resource]

        if alias and GetConvarInt('ox:dependencyAlias', 1) ~= 0 and GetResourceState(alias) == 'started' then
            return true
        end

        if printMessage then return print(msg) end

        return false, msg
    end

    return ok
end
