-- Forwarder for stock qb-core shared/main.lua + shared/functions.lua: defines
-- the QBShared global with the stock helper functions in the including
-- resource's VM. Pure helpers are reimplemented locally (functions cannot be
-- relied on across the export boundary); data tables are pulled from kora_core.
-- Pass-through only: defaults never overwrite values the consumer already set.
QBShared = QBShared or {}
local F = assert(load(assert(LoadResourceFile('qb-core', 'shared/_forward.lua'), '[qb-core-wrapper] missing shared/_forward.lua'), '@qb-core/shared/_forward.lua'))()

local StringCharset, NumberCharset = {}, {}
for i = 48, 57 do NumberCharset[#NumberCharset + 1] = string.char(i) end
for i = 65, 90 do StringCharset[#StringCharset + 1] = string.char(i) end
for i = 97, 122 do StringCharset[#StringCharset + 1] = string.char(i) end

local function default(key, value)
    if QBShared[key] == nil then QBShared[key] = value end
end

default('RandomStr', function(length)
    if length <= 0 then return '' end
    return QBShared.RandomStr(length - 1) .. StringCharset[math.random(1, #StringCharset)]
end)

default('RandomInt', function(length)
    if length <= 0 then return '' end
    return QBShared.RandomInt(length - 1) .. NumberCharset[math.random(1, #NumberCharset)]
end)

default('SplitStr', function(str, delimiter)
    local result = {}
    local from = 1
    local delimFrom, delimTo = string.find(str, delimiter, from, true)
    while delimFrom do
        result[#result + 1] = string.sub(str, from, delimFrom - 1)
        from = delimTo + 1
        delimFrom, delimTo = string.find(str, delimiter, from, true)
    end
    result[#result + 1] = string.sub(str, from)
    return result
end)

default('Trim', function(value)
    if not value then return nil end
    return (string.gsub(value, '^%s*(.-)%s*$', '%1'))
end)

default('FirstToUpper', function(value)
    if not value then return nil end
    return (value:gsub('^%l', string.upper))
end)

default('Round', function(value, numDecimalPlaces)
    if not numDecimalPlaces then return math.floor(value + 0.5) end
    local power = 10 ^ numDecimalPlaces
    return math.floor((value * power) + 0.5) / power
end)

default('IsFunction', function(value)
    if type(value) == 'function' then return true end
    return type(value) == 'table' and type(rawget(value, '__cfx_functionReference')) == 'string'
end)

default('ChangeVehicleExtra', function(vehicle, extra, enable)
    if DoesExtraExist(vehicle, extra) then
        if enable then
            SetVehicleExtra(vehicle, extra, false)
            if not IsVehicleExtraTurnedOn(vehicle, extra) then
                QBShared.ChangeVehicleExtra(vehicle, extra, enable)
            end
        else
            SetVehicleExtra(vehicle, extra, true)
            if IsVehicleExtraTurnedOn(vehicle, extra) then
                QBShared.ChangeVehicleExtra(vehicle, extra, enable)
            end
        end
    end
end)

default('SetDefaultVehicleExtras', function(vehicle, config)
    for i = 1, 20 do
        if DoesExtraExist(vehicle, i) then SetVehicleExtra(vehicle, i, true) end
    end
    if type(config) ~= 'table' then return end
    for id, enabled in pairs(config) do
        QBShared.ChangeVehicleExtra(vehicle, tonumber(id), enabled)
    end
end)

-- Data tables defined in stock's shared/main.lua.
for _, key in ipairs({ 'StarterItems', 'MaleNoGloves', 'FemaleNoGloves' }) do
    if QBShared[key] == nil then QBShared[key] = F.shared(key) end
end
default('ForceJobDefaultDutyAtLogin', true)
