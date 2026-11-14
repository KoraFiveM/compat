--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

local settings = require 'resource.settings'

local function loadLocaleFile(key)
    local file = LoadResourceFile(cache.resource, ('locales/%s.json'):format(key))
        or LoadResourceFile(cache.resource, 'locales/en.json')

    return file and json.decode(file) or {}
end

function lib.getLocaleKey() return settings.locale end

---@param key string
function lib.setLocale(key)
    TriggerEvent('ox_lib:setLocale', key)
    exports.kora_lib:ox_setLocale(key, loadLocaleFile(key), GetInvokingResource() or cache.resource)
end

lib.locale(settings.locale)
exports.kora_lib:ox_setLocale(settings.locale, loadLocaleFile(settings.locale), cache.resource)
