local debug_getinfo = debug.getinfo

function noop() end

lib = setmetatable({
    name = 'ox_lib',
    context = IsDuplicityVersion() and 'server' or 'client',
}, {
    __newindex = function(self, key, fn)
        rawset(self, key, fn)

        if debug_getinfo(2, 'S').short_src:find('@ox_lib/resource') then
            exports(key, fn)
        end
    end,

    __index = function(self, key)
        local dir = ('imports/%s'):format(key)
        local chunk = LoadResourceFile(self.name, ('%s/%s.lua'):format(dir, self.context))
        local shared = LoadResourceFile(self.name, ('%s/shared.lua'):format(dir))

        if shared then
            chunk = (chunk and ('%s\n%s'):format(shared, chunk)) or shared
        end

        if chunk then
            local fn, err = load(chunk, ('@@ox_lib/%s/%s.lua'):format(key, self.context))

            if not fn or err then
                return error(('\n^1Error importing module (%s): %s^0'):format(dir, err), 3)
            end

            rawset(self, key, fn() or noop)

            return self[key]
        end
    end
})

cache = {
    resource = lib.name,
    game = GetGameName(),
}

-- This compatibility resource intentionally has no NUI page of its own.
-- kora_lib owns the single shared browser surface; keeping ox_lib headless avoids
-- a second permanent renderer and duplicate focus ownership.
function lib.hasLoaded()
    if GetResourceState('kora_lib') == 'started' then return true end

    return '^1qblib must be started before ox_lib compatibility consumers.^0'
end

require = lib.require
