local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local resourcesRoot = scriptDir .. '../../../../'
local koraLibTestDir = resourcesRoot .. '[test]/kora_lib/test/'
package.path = koraLibTestDir .. '?.lua;' .. package.path

local H = require('harness')
local mocks = require('mocks')
local net = mocks.install()
local exports = {}
_G.exports = function(name, callback) exports[name] = callback end

dofile(scriptDir .. '../../server.lua')

H.test('clients cannot relay arbitrary PolyZone events', function()
    _G.source = 42
    net.fire('PolyZone:TriggerZoneEvent', 'legacy:event', 'payload')
    _G.source = nil

    H.assertEqual(#net.triggeredClientEvents, 0)
end)

H.test('server event and export relay valid legacy messages', function()
    _G.source = 0
    net.fire('PolyZone:TriggerZoneEvent', 'legacy:event', 'from-server')
    _G.source = nil
    exports.TriggerZoneEvent('legacy:export', 'from-export')

    H.assertEqual(#net.triggeredClientEvents, 2)
    H.assertEqual(net.triggeredClientEvents[1].name, '__PolyZone__:legacy:event')
    H.assertEqual(net.triggeredClientEvents[1].target, -1)
    H.assertEqual(net.triggeredClientEvents[1][1], 'from-server')
    H.assertEqual(net.triggeredClientEvents[2].name, '__PolyZone__:legacy:export')
    H.assertEqual(net.triggeredClientEvents[2][1], 'from-export')
end)

H.test('server relay rejects malformed event names', function()
    H.assertThrows(function() exports.TriggerZoneEvent('') end)
    H.assertThrows(function() exports.TriggerZoneEvent(false) end)
end)

H.report('polyzone_server')
