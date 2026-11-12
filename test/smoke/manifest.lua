-- Keeps FiveM's filename-based @PolyZone imports intact. `provide` cannot
-- substitute these files, so the manifest and their order are part of the
-- wrapper's compatibility contract.
local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local resourcesRoot = scriptDir .. '../../../../'
local koraLibTestDir = resourcesRoot .. '[test]/kora_lib/test/'
package.path = koraLibTestDir .. '?.lua;' .. package.path

local H = require('harness')
local polyZoneRoot = scriptDir .. '../../'
local manifestFile = assert(io.open(polyZoneRoot .. 'fxmanifest.lua', 'r'))
local manifest = manifestFile:read('*a')
manifestFile:close()

H.test('manifest keeps every legacy import file in upstream order', function()
    H.assertTrue(manifest:find("dependency 'kora_lib'", 1, true) ~= nil,
        'PolyZone must declare kora_lib so its shim cannot start without its implementation')
    H.assertTrue(manifest:find("'@kora_lib/init.lua'", 1, true) ~= nil)

    local previous = 0
    for _, name in ipairs({ 'client.lua', 'BoxZone.lua', 'EntityZone.lua', 'CircleZone.lua', 'ComboZone.lua' }) do
        local file = assert(io.open(polyZoneRoot .. name, 'r'), ('Missing @PolyZone/%s import file.'):format(name))
        file:close()
        local position = assert(manifest:find("'" .. name .. "'", 1, true), ('Manifest omits @PolyZone/%s.'):format(name))
        H.assertTrue(position > previous, ('@PolyZone/%s is out of order.'):format(name))
        previous = position
    end
end)

H.report('polyzone_manifest')
