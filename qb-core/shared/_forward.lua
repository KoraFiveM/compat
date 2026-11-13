-- Internal helper for the wrapper's forwarding files. Each public file
-- (shared/items.lua, ...) is executed in the CONSUMER's VM, loads this file via
-- LoadResourceFile and gets back a table of pull helpers. Returns the table.
-- Data always comes from kora_core's qb-core compat exports at load time;
-- every pull is pcall-guarded so a not-yet-started kora_core yields an empty
-- table (plus a warning) instead of a hard script error in the consumer.
local F = {}

local function try(fn)
    local ok, result = pcall(fn)
    if ok then return result end
    return nil
end

local function warn(msg)
    print(('^3[qb-core-wrapper] %s^7'):format(msg))
end

-- Pull a QBCore.Shared namespace ('Items', 'Jobs', ...). Prefers the
-- GetShared export; falls back to GetCoreObject({'Shared'}).
function F.shared(namespace)
    local data = try(function() return exports['qb-core']:GetShared(namespace) end)
    if type(data) == 'table' then return data end
    local core = try(function() return exports['qb-core']:GetCoreObject({ 'Shared' }) end)
    if type(core) == 'table' and type(core.Shared) == 'table' and type(core.Shared[namespace]) == 'table' then
        return core.Shared[namespace]
    end
    warn(('could not read Shared.%s from kora_core -- ensure kora_core before qb-core'):format(namespace))
    return {}
end

-- Pull QBCore.Config (what stock scripts see as QBConfig).
function F.config()
    local core = try(function() return exports['qb-core']:GetCoreObject({ 'Config' }) end)
    if type(core) == 'table' and type(core.Config) == 'table' then return core.Config end
    warn('could not read Config from kora_core -- ensure kora_core before qb-core')
    return nil
end

return F
