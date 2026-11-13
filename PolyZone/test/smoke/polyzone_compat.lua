-- Pins the five backward-compat bugs found in this shim: PolyZone dropping
-- minZ/maxZ, CircleZone ignoring useZ, CircleZone not baking its callbacks
-- in at creation time, ComboZone double-creating kora_lib zones while leaking
-- its children's originals, and colon-calling the dot-function `remove`.
--
-- Loads kora_lib's REAL zones module (not a mock of it) -- a same-VM Lua
-- simulation with a mocked zones module previously masked these bugs; only
-- testing against the actual kora_lib/modules/zones/client.lua containment
-- logic catches them. Kora is set directly here rather than through the
-- shim's LoadResourceFile bootstrap (that self-bootstrap path already has
-- its own coverage from an earlier session).
local scriptDir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
-- Resolved from the resources/ root rather than as a sibling hop: this shim
-- lives in resources/[compat]/ while kora_lib lives in resources/[test]/, so a
-- plain "../../../kora_lib/" (which assumed both sat in the same category
-- folder) no longer reaches it. Category folders are a server-side
-- organisational choice, so keep this anchored on the resources/ root -- it
-- survives either resource being re-filed again.
local resourcesRoot = scriptDir .. "../../../../"
local koraLibTestDir = resourcesRoot .. "[test]/kora_lib/test/"
local koraLibRoot = koraLibTestDir .. "../"
package.path = koraLibTestDir .. "?.lua;" .. package.path

local harness = require("harness")
local mocks = require("mocks")
local net = mocks.install()

dofile(koraLibRoot .. "config.lua")
dofile(koraLibRoot .. "build/initiate.lua")
dofile(koraLibRoot .. "modules/util/shared.lua")

-- The mock player starts at the origin; only the tick-loop natives
-- need to exist so the first zone creation's ensureTickThread doesn't error.
-- Every assertion below drives containment through the pure `contains`
-- function directly, not through the tick loop, so where the mock player
-- sits doesn't matter.
_G.PlayerPedId = function() return 1 end
local playerCoords = { x = 0, y = 0, z = 0 }
local entityCoords = { x = 0, y = 0, z = 0 }
_G.vector2 = function(x, y) return { x = x, y = y } end
_G.GetEntityCoords = function(entity)
    if entity == 99 then return entityCoords end
    return playerCoords
end
_G.GetEntitySpeed = function() return 0.0 end
local trackedEntityExists = true
_G.DoesEntityExist = function(entity) return entity == 1 or (entity == 99 and trackedEntityExists) end
_G.GetEntityModel = function() return 1 end
_G.GetModelDimensions = function() return { x = -1, y = -1, z = -1 }, { x = 1, y = 1, z = 1 } end
_G.GetOffsetFromEntityGivenWorldCoords = function(_, x, y, z)
    return { x = x - entityCoords.x, y = y - entityCoords.y, z = z - entityCoords.z }
end
_G.GetOffsetFromEntityInWorldCoords = function(_, x, y, z)
    return { x = x + entityCoords.x, y = y + entityCoords.y, z = z + entityCoords.z }
end
_G.DrawLine = function() end
_G.DrawMarker = function() end
_G.DrawPoly = function() end
local createdBlips, removedBlips = {}, {}
_G.AddBlipForCoord = function(x, y, z)
    local blip = #createdBlips + 1
    createdBlips[blip] = { x = x, y = y, z = z }
    return blip
end
_G.SetBlipColour = function() end
_G.SetBlipDisplay = function() end
_G.SetBlipScale = function() end
_G.SetBlipAsShortRange = function() end
_G.SetBlipCoords = function(blip, x, y, z) createdBlips[blip] = { x = x, y = y, z = z } end
_G.RemoveBlip = function(blip) removedBlips[blip] = true end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end

dofile(koraLibRoot .. "modules/raycast/client.lua")
dofile(koraLibRoot .. "local/resources/client.lua")
dofile(koraLibRoot .. "modules/theme/shared.lua")
dofile(koraLibRoot .. "modules/util/shared.lua")
-- The real kora_lib manifest loads the keybind module before zones. This focused
-- compatibility test never starts the interactive creator, so a registration
-- stub keeps that unrelated dependency out while preserving production order.
Kora.keybind.add = function() return {} end
dofile(koraLibRoot .. "modules/zones/client.lua")

-- Load the shim itself. client.lua's `if Kora == nil then ... end` bootstrap
-- is skipped since Kora is already the real proxy from build/initiate.lua.
local polyZoneRoot = scriptDir .. "../../"
dofile(polyZoneRoot .. "client.lua")
dofile(polyZoneRoot .. "BoxZone.lua")
dofile(polyZoneRoot .. "EntityZone.lua")
dofile(polyZoneRoot .. "CircleZone.lua")
dofile(polyZoneRoot .. "ComboZone.lua")

harness.test("PolyZone wrappers retain their public legacy method surface", function()
    local expected = {
        { PolyZone, {
            'Create', 'new', 'isPointInside', 'onPlayerInOut', 'onPointInOut', 'destroy', 'remove',
            'TransformPoint', 'draw', 'drawPoly', 'setPaused', 'isPaused', 'getBoundingBoxMin',
            'getBoundingBoxMax', 'getBoundingBoxSize', 'getBoundingBoxCenter', 'addDebugBlip',
            'removeDebugBlip', 'addEvent', 'removeEvent', 'getPlayerPosition', 'getPlayerHeadPosition',
            'ensureMetatable', 'rotate',
        } },
        { BoxZone, {
            'Create', 'new', 'isPointInside', 'onPlayerInOut', 'destroy', 'remove', 'TransformPoint',
            'draw', 'getHeading', 'setHeading', 'getCenter', 'setCenter', 'getLength', 'setLength',
            'getWidth', 'setWidth', 'calculateMinAndMaxZ', 'setPaused', 'isPaused',
        } },
        { CircleZone, {
            'Create', 'new', 'isPointInside', 'onPlayerInOut', 'destroy', 'remove', 'draw', 'getRadius',
            'setRadius', 'getCenter', 'setCenter', 'setPaused', 'isPaused',
        } },
        { ComboZone, {
            'Create', 'new', 'getZones', 'AddZone', 'RemoveZone', 'isPointInside',
            'isPointInsideExhaustive', 'onPointInOut', 'onPointInOutExhaustive', 'onPlayerInOut',
            'onPlayerInOutExhaustive', 'draw', 'printInfo', 'addDebugBlip', 'removeDebugBlip',
            'addEvent', 'removeEvent', 'destroy', 'remove', 'setPaused', 'isPaused',
        } },
        { EntityZone, {
            'Create', 'new', 'isPointInside', 'onPlayerInOut', 'onEntityDamaged', 'TransformPoint',
            'draw', 'addDebugBlip', 'destroy', 'remove', 'setPaused', 'isPaused',
        } },
    }

    for i = 1, #expected do
        local api, methods = expected[i][1], expected[i][2]
        for j = 1, #methods do
            harness.assertEqual(type(api[methods[j]]), 'function', ('missing PolyZone API %s'):format(methods[j]))
        end
    end
end)

harness.test("PolyZone forwards minZ/maxZ instead of dropping them", function()
    local zone = PolyZone:Create(
        { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 0, y = 10 } },
        { minZ = 25, maxZ = 35 }
    )
    harness.assertTrue(
        zone:isPointInside({ x = 5, y = 5, z = 30 }),
        "a point at real elevation inside minZ/maxZ must be inside (this is the qb-banking/qb-recyclejob 'onEnter never fires' bug)"
    )
    harness.assertFalse(
        zone:isPointInside({ x = 5, y = 5, z = 0 }),
        "a point at z=0 -- where the band would have been anchored if minZ/maxZ were dropped -- must now be OUTSIDE"
    )
end)

harness.test("PolyZone without height bounds ignores elevation", function()
    local transitions = {}
    playerCoords = { x = 2, y = 2, z = 99999 }
    local zone = PolyZone:Create({
        vector3(0, 0, 0), vector3(10, 0, 0), vector3(0, 10, 0),
    }, {})

    harness.assertTrue(zone:isPointInside({ x = 2, y = 2, z = 99999 }),
        "legacy PolyZone without minZ/maxZ must remain a pure XY footprint")
    harness.assertFalse(zone:isPointInside({ x = 20, y = 20, z = 0 }),
        "ignoring elevation must not expand the XY footprint")
    zone:onPlayerInOut(function(isInside) transitions[#transitions + 1] = isInside end)
    net.step()
    harness.assertEqual(transitions[1], true,
        "the shared-grid callback must enter an elevation-free legacy polygon")
    zone:destroy()
    playerCoords = { x = 0, y = 0, z = 0 }
end)

harness.test('PolyZone validates points and height bands before constructing a kora_lib zone', function()
    harness.assertFalse(pcall(function() PolyZone:Create(false, {}) end))
    harness.assertFalse(pcall(function()
        PolyZone:Create({ { x = 0, y = 0 }, { x = 1, y = 0 }, [4] = { x = 0, y = 1 } }, {})
    end))
    harness.assertFalse(pcall(function()
        PolyZone:Create({ { x = 0, y = 0 }, { x = math.huge, y = 0 }, { x = 0, y = 1 } }, {})
    end))
    harness.assertFalse(pcall(function()
        PolyZone:Create({ { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 0, y = 1 } }, { minZ = 1 })
    end))
    harness.assertFalse(pcall(function()
        PolyZone:Create({ { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 0, y = 1 } }, { thickness = 0 / 0 })
    end))
end)

harness.test("PolyZone exposes cached upstream bounding geometry", function()
    local zone = PolyZone:Create({
        vector3(-2, -1, 0), vector3(4, -1, 0), vector3(4, 3, 0), vector3(-2, 3, 0),
    }, {})

    harness.assertTrue(zone.isPolyZone, 'poly zones must retain their upstream type marker')
    harness.assertEqual(zone:getBoundingBoxMin().x, -2, 'minimum X should be cached at creation')
    harness.assertEqual(zone:getBoundingBoxMax().y, 3, 'maximum Y should be cached at creation')
    harness.assertEqual(zone:getBoundingBoxSize().x, 6, 'bounding width should match the polygon')
    harness.assertEqual(zone:getBoundingBoxCenter().y, 1, 'bounding center should match the polygon')
    harness.assertEqual(zone.area, 24, 'area should use the polygon footprint')
    harness.assertEqual(zone:TransformPoint(zone.points[1]), zone.points[1], 'plain PolyZones do not transform points')
    zone:destroy()
end)

harness.test("PolyZone.rotate preserves the upstream XY rotation helper", function()
    local rotated = PolyZone.rotate({ x = 1, y = 1 }, { x = 2, y = 1 }, 90)
    harness.assertEqual(rotated.x, 1, 'rotation should keep the origin-relative X coordinate')
    harness.assertEqual(rotated.y, 2, 'rotation should turn positive X toward positive Y')
    harness.assertFalse(pcall(function()
        PolyZone.rotate({ x = math.huge, y = 1 }, { x = 2, y = 1 }, 90)
    end), 'rotation must reject non-finite origins')
    harness.assertFalse(pcall(function()
        PolyZone.rotate({ x = 1, y = 1 }, { x = 2, y = 1 }, math.huge)
    end), 'rotation must reject non-finite angles')
end)

harness.test("PolyZone draw retains its manual outline and wall helper", function()
    local originalDrawLine, originalDrawPoly = DrawLine, DrawPoly
    local lines, walls = {}, {}
    _G.DrawLine = function(...) lines[#lines + 1] = { ... } end
    _G.DrawPoly = function(...) walls[#walls + 1] = { ... } end

    local zone = PolyZone:Create({
        vector3(0, 0, 0), vector3(2, 0, 0), vector3(0, 2, 0),
    }, { minZ = 10, maxZ = 20 })
    zone:draw()
    harness.assertEqual(#lines, 0, 'draw should require debug settings or forceDraw')
    PolyZone.drawPoly(zone, true)
    harness.assertEqual(#lines, 6, 'a triangle should render each vertical and top outline edge')
    harness.assertEqual(#walls, 12, 'a triangle should render two-sided walls for each edge')
    harness.assertEqual(lines[1][3], 10, 'manual draw should honor the configured floor')
    harness.assertEqual(lines[1][6], 20, 'manual draw should honor the configured ceiling')

    zone:destroy()
    _G.DrawLine, _G.DrawPoly = originalDrawLine, originalDrawPoly
end)

harness.test("PolyZone ensureMetatable restores legacy zone methods without creating a zone", function()
    local box = PolyZone.ensureMetatable({ isBoxZone = true, heading = 42 })
    local circle = PolyZone.ensureMetatable({ isCircleZone = true, radius = 3 })
    local poly = PolyZone.ensureMetatable({ isPolyZone = true })

    harness.assertEqual(box:getHeading(), 42, 'restored BoxZone tables should expose BoxZone methods')
    harness.assertEqual(circle:getRadius(), 3, 'restored CircleZone tables should expose CircleZone methods')
    harness.assertEqual(poly:TransformPoint(poly), poly, 'restored PolyZone tables should expose base methods')
    harness.assertEqual(PolyZone.ensureMetatable('not-a-zone'), 'not-a-zone', 'non-tables should remain untouched')
end)

harness.test("debug blips use the zone center and are removed on destroy", function()
    local zone = PolyZone:Create({
        vector3(-2, -2, 0), vector3(2, -2, 0), vector3(2, 2, 0), vector3(-2, 2, 0),
    }, {})
    local blip = zone:addDebugBlip()

    harness.assertEqual(createdBlips[blip].x, 0, 'debug blip should use the bounding-box center')
    harness.assertEqual(createdBlips[blip].y, 0, 'debug blip should use the bounding-box center')
    zone:destroy()
    harness.assertTrue(removedBlips[blip], 'destroy must release the debug blip')
end)

harness.test("debugBlip creation options retain PolyZone's one-time helper", function()
    local createdBefore = #createdBlips
    local poly = PolyZone:Create({ vector3(-1, -1, 0), vector3(1, -1, 0), vector3(0, 1, 0) }, { debugBlip = true })
    local box = BoxZone:Create({ x = 0, y = 0, z = 0 }, 2, 2, { debugBlip = true })
    local circle = CircleZone:Create({ x = 0, y = 0, z = 0 }, 1, { debugBlip = true })
    local entity = EntityZone:Create(99, { debugBlip = true })
    local combo = ComboZone:Create({ poly, box }, { debugBlip = true })

    harness.assertTrue(poly.debugBlip and box.debugBlip and circle.debugBlip and entity.debugBlip,
        'shape creation should honor debugBlip')
    harness.assertEqual(#combo.debugBlips, 2, 'ComboZone creation should delegate debug blips to children')
    harness.assertEqual(#createdBlips - createdBefore, 6, 'creation should allocate one blip per requested shape or combo child')

    combo:destroy()
    circle:destroy()
    entity:destroy()
end)

harness.test("every shape requires a boolean debugBlip option", function()
    harness.assertFalse(pcall(function()
        PolyZone:Create({ vector3(-1, -1, 0), vector3(1, -1, 0), vector3(0, 1, 0) }, { debugBlip = 1 })
    end), 'PolyZone debugBlip must reject non-booleans')
    harness.assertFalse(pcall(function() BoxZone:Create({ x = 0, y = 0, z = 0 }, 2, 2, { debugBlip = 'yes' }) end),
        'BoxZone debugBlip must reject non-booleans')
    harness.assertFalse(pcall(function() CircleZone:Create({ x = 0, y = 0, z = 0 }, 1, { debugBlip = 1 }) end),
        'CircleZone debugBlip must reject non-booleans')
    harness.assertFalse(pcall(function() EntityZone:Create(99, { debugBlip = 'yes' }) end),
        'EntityZone debugBlip must reject non-booleans')
    harness.assertFalse(pcall(function() ComboZone:Create({}, { debugBlip = 1 }) end),
        'ComboZone debugBlip must reject non-booleans')
end)

harness.test("PolyZone addEvent routes only while inside and removeEvent detaches it", function()
    local calls = 0
    AddEventHandler('smoke:zone-event', function(value)
        calls = calls + value
    end)
    local zone = PolyZone:Create({ { x = -2, y = -2 }, { x = 2, y = -2 }, { x = 2, y = 2 }, { x = -2, y = 2 } }, {})
    zone:addEvent('smoke:zone-event')
    net.fire('__PolyZone__:smoke:zone-event', 1)
    zone:removeEvent('smoke:zone-event')
    net.fire('__PolyZone__:smoke:zone-event', 10)

    harness.assertEqual(calls, 1, "removeEvent must detach the internal route instead of leaving a live callback")
    zone:destroy()
end)

harness.test("destroying an event zone detaches its internal route", function()
    local calls = 0
    AddEventHandler('smoke:destroy-event', function() calls = calls + 1 end)

    local zone = PolyZone:Create({
        vector3(-5, -5, 0), vector3(5, -5, 0), vector3(5, 5, 0), vector3(-5, 5, 0),
    }, {})

    zone:addEvent('smoke:destroy-event')
    zone:destroy()
    net.fire('__PolyZone__:smoke:destroy-event')

    harness.assertEqual(calls, 0, 'destroy must detach event routes rather than retaining callbacks')
end)

harness.test("CircleZone with useZ=false (the default) ignores elevation", function()
    local zone = CircleZone:Create({ x = 0, y = 0, z = 10 }, 3, { useZ = false })
    harness.assertTrue(
        zone:isPointInside({ x = 1, y = 1, z = 500 }),
        "a point within radius in XY but far away in Z must be inside when useZ=false"
    )
    harness.assertFalse(
        zone:isPointInside({ x = 100, y = 100, z = 10 }),
        "a point far outside the radius in XY must be outside regardless of Z"
    )
    local edgeAngle = math.pi / 24
    harness.assertTrue(
        zone:isPointInside({ x = 2.99 * math.cos(edgeAngle), y = 2.99 * math.sin(edgeAngle), z = -99999 }),
        "a point just inside the true radial boundary must not be cut off by a polygon approximation"
    )
    harness.assertFalse(
        zone:isPointInside({ x = 3, y = 0, z = -99999 }),
        "PolyZone CircleZone must retain its exclusive radius boundary"
    )
    zone:destroy()
end)

harness.test("CircleZone validates geometry and core options before creating a kora_lib zone", function()
    harness.assertFalse(pcall(function() CircleZone:Create({ x = 0, y = 0 }, 3, {}) end))
    harness.assertFalse(pcall(function() CircleZone:Create({ x = math.huge, y = 0, z = 0 }, 3, {}) end))
    harness.assertFalse(pcall(function() CircleZone:Create({ x = 0, y = 0, z = 0 }, math.huge, {}) end))
    harness.assertFalse(pcall(function() CircleZone:Create({ x = 0, y = 0, z = 0 }, 3, false) end))
    harness.assertFalse(pcall(function() CircleZone:Create({ x = 0, y = 0, z = 0 }, 3, { useZ = 'yes' }) end))

    local circle = CircleZone:Create({ x = 0, y = 0, z = 0 }, 3, {})
    harness.assertFalse(pcall(function() circle:setCenter({ x = 0, y = 0 }) end))
    harness.assertFalse(pcall(function() circle:setRadius(0 / 0) end))
    circle:destroy()
end)

harness.test("CircleZone draw preserves PolyZone's manual debug markers", function()
    local originalDrawMarker = DrawMarker
    local markers = {}
    _G.DrawMarker = function(...) markers[#markers + 1] = { ... } end

    local flat = CircleZone:Create({ x = 1, y = 2, z = 3 }, 4, {})
    flat:draw()
    harness.assertEqual(#markers, 0, 'draw should require debugPoly or forceDraw')
    flat:draw(true)
    harness.assertEqual(markers[1][1], 1, 'flat circles should use PolyZone\'s cylinder marker')
    harness.assertEqual(markers[1][4], -500.0, 'flat circle marker should span the legacy vertical band')
    harness.assertEqual(markers[1][11], 8.0, 'flat circle marker should use the diameter')

    local sphere = CircleZone:Create({ x = 1, y = 2, z = 3 }, 4, { useZ = true })
    sphere:draw(true)
    harness.assertEqual(markers[2][1], 28, '3D circles should use PolyZone\'s sphere marker')
    harness.assertEqual(markers[2][4], 3, '3D circle marker should use the zone elevation')
    harness.assertEqual(markers[2][11], 4.0, '3D circle marker should use the radius')

    flat:destroy()
    sphere:destroy()
    _G.DrawMarker = originalDrawMarker
end)

harness.test("BoxZone exposes mutable geometry helpers", function()
    local box = BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 2, { heading = 0 })
    harness.assertEqual(box:getHeading(), 0, "getHeading should expose the creation heading")
    harness.assertEqual(box:getLength(), 4, "getLength should expose the creation length")
    harness.assertEqual(box:getWidth(), 2, "getWidth should expose the creation width")
    harness.assertEqual(box:getCenter().x, 0, "getCenter should expose the current center")

    box:setCenter({ x = 10, y = 0, z = 0 }):setLength(8):setWidth(4):setHeading(90)
    harness.assertEqual(box:getCenter().x, 10, "setCenter should rebuild at the new center")
    harness.assertEqual(box:getLength(), 8, "setLength should retain the new length")
    harness.assertEqual(box:getWidth(), 4, "setWidth should retain the new width")
    harness.assertEqual(box:getHeading(), 90, "setHeading should retain the new heading")
    harness.assertTrue(box:isPointInside({ x = 10, y = 0, z = 0 }), "the rebuilt box should contain its new center")
    box:destroy()
end)

harness.test("BoxZone without height bounds ignores elevation", function()
    local transitions = {}
    playerCoords = { x = 0, y = 0, z = 99999 }
    local zone = BoxZone:Create({ x = 0, y = 0, z = 0 }, 10, 10, {})

    harness.assertTrue(zone:isPointInside({ x = 0, y = 0, z = 99999 }),
        "legacy BoxZone without minZ/maxZ must remain an XY rectangle")
    harness.assertFalse(zone:isPointInside({ x = 6, y = 0, z = 0 }),
        "ignoring elevation must not expand BoxZone's XY bounds")
    zone:onPlayerInOut(function(isInside) transitions[#transitions + 1] = isInside end)
    net.step()
    harness.assertEqual(transitions[1], true,
        "the shared-grid callback must enter an elevation-free legacy box")
    zone:destroy()
    playerCoords = { x = 0, y = 0, z = 0 }
end)

harness.test('BoxZone validates geometry and directional bounds before rebuilding', function()
    harness.assertFalse(pcall(function() BoxZone:Create({ x = 0, y = 0 }, 4, 4, {}) end))
    harness.assertFalse(pcall(function() BoxZone:Create({ x = 0, y = 0, z = 0 }, math.huge, 4, {}) end))
    harness.assertFalse(pcall(function() BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, false) end))
    harness.assertFalse(pcall(function()
        BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, { scale = { 1, [3] = 1 } })
    end))
    harness.assertFalse(pcall(function()
        BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, { offset = { 0, 0, math.huge } })
    end))
    harness.assertFalse(pcall(function()
        BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, { minZ = 0 })
    end), 'a partial BoxZone height band must not silently fall back to default height')
    harness.assertFalse(pcall(function()
        BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, { minZ = 0, maxZ = math.huge })
    end), 'a non-finite BoxZone height band must fail before geometry calculations')
    harness.assertFalse(pcall(function()
        BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, { minZ = 4, maxZ = 4 })
    end), 'a zero-height BoxZone band must fail before building a kora_lib zone')
    harness.assertFalse(pcall(function()
        BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, {
            minZ = 0, maxZ = 10, offset = { 0, 0, 0, 0, -6, -6 },
        })
    end), 'directional bounds must not invert a BoxZone before kora_lib zone creation')

    local box = BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, {})
    harness.assertFalse(pcall(function() box:setHeading(0 / 0) end))
    harness.assertFalse(pcall(function() box:setCenter({ x = 0, y = 0 }) end))
    harness.assertFalse(pcall(function() box:setLength(math.huge) end))
    harness.assertFalse(pcall(function() box:setWidth(0) end))
    box:destroy()
end)

harness.test("BoxZone uses its rebuilt geometry for inherited manual draw", function()
    local originalDrawLine, originalDrawPoly = DrawLine, DrawPoly
    local lines, walls = {}, {}
    _G.DrawLine = function(...) lines[#lines + 1] = { ... } end
    _G.DrawPoly = function(...) walls[#walls + 1] = { ... } end

    local box = BoxZone:Create({ x = 0, y = 0, z = 0 }, 8, 4, { heading = 90, minZ = 2, maxZ = 6 })
    local transformed = box:TransformPoint({ x = 0, y = 4, z = 3 })
    harness.assertEqual(transformed.x, -4, 'BoxZone TransformPoint should rotate around its configured center')
    harness.assertTrue(math.abs(transformed.y) < 0.000001, 'BoxZone TransformPoint should preserve the rotated axis')
    harness.assertEqual(transformed.z, 3, 'BoxZone TransformPoint should preserve elevation')
    box:draw()
    harness.assertEqual(#lines, 0, 'inherited draw should require debug settings or forceDraw')
    box:draw(true)
    harness.assertEqual(#lines, 8, 'a box should render each vertical and top outline edge')
    harness.assertEqual(#walls, 16, 'a box should render two-sided walls for every edge')
    harness.assertEqual(lines[1][3], 2, 'box draw should retain its lower bound')
    harness.assertEqual(lines[1][6], 6, 'box draw should retain its upper bound')

    box:destroy()
    _G.DrawLine, _G.DrawPoly = originalDrawLine, originalDrawPoly
end)

harness.test("BoxZone applies legacy scale and offset bounds", function()
    local box = BoxZone:Create({ x = 0, y = 0, z = 0 }, 10, 10, {
        minZ = 0,
        maxZ = 10,
        scale = { 1, 1, 0.5, 0.5, 0.5, 0.5 },
        offset = { 2, 0, 0, 0, 1, 1 },
    })

    harness.assertTrue(box:isPointInside({ x = 0, y = 6, z = 5 }), 'forward offset should extend the box')
    harness.assertFalse(box:isPointInside({ x = 0, y = -6, z = 5 }), 'the unextended opposite side should stay outside')
    harness.assertFalse(box:isPointInside({ x = 3, y = 0, z = 5 }), 'symmetric width scaling should shrink side bounds')
    harness.assertTrue(box:isPointInside({ x = 0, y = 0, z = 8 }), 'Z offset and scale should adjust explicit height bounds')
    harness.assertFalse(box:isPointInside({ x = 0, y = 0, z = 9 }), 'the adjusted height ceiling should be enforced')
    box:destroy()
end)

harness.test("BoxZone.calculateMinAndMaxZ matches directional vertical geometry", function()
    local minZ, maxZ = BoxZone.calculateMinAndMaxZ(0, 10, { 0.5, 2 }, { 1, 3 })
    harness.assertEqual(minZ, 1.5, 'minimum Z should scale from center then apply offset')
    harness.assertEqual(maxZ, 18, 'maximum Z should scale from center then apply offset')
end)

harness.test("BoxZone keeps PolyZone's length/width axes and heading direction", function()
    local box = BoxZone:Create({ x = 0, y = 0, z = 0 }, 10, 2, { heading = 90 })

    harness.assertTrue(box:isPointInside({ x = -4, y = 0, z = 0 }), 'a 90-degree heading should rotate length onto the X axis')
    harness.assertFalse(box:isPointInside({ x = 0, y = 4, z = 0 }), 'the narrow width must not become the long axis')
    box:destroy()
end)

harness.test("BoxZone:new keeps the legacy box constructor signature", function()
    local box = BoxZone:new({ x = 0, y = 0, z = 0 }, 4, 4, {})
    harness.assertTrue(box:isPointInside({ x = 0, y = 0, z = 0 }),
        "BoxZone:new must create a box rather than falling through to PolyZone:new")
    box:destroy()
end)

harness.test("same-value BoxZone and CircleZone centers avoid backing-zone rebuilds", function()
    local realBox, realSphere = Kora.zones.box, Kora.zones.sphere
    local boxCalls, sphereCalls = 0, 0
    Kora.zones.box = function(opts)
        boxCalls = boxCalls + 1
        return realBox(opts)
    end
    Kora.zones.sphere = function(opts)
        sphereCalls = sphereCalls + 1
        return realSphere(opts)
    end

    local box = BoxZone:Create({ x = 1, y = 2, z = 3 }, 4, 4, {})
    local boxCenter = { x = 1, y = 2, z = 3 }
    box:setCenter(boxCenter)
    harness.assertEqual(boxCalls, 1, 'a same-value BoxZone center must not rebuild the kora_lib zone')
    harness.assertEqual(box:getCenter(), boxCenter, 'BoxZone should still retain the supplied center value')

    local circle = CircleZone:Create({ x = 1, y = 2, z = 3 }, 4, { useZ = true })
    local circleCenter = { x = 1, y = 2, z = 3 }
    circle:setCenter(circleCenter)
    harness.assertEqual(sphereCalls, 1, 'a same-value CircleZone center must not rebuild the kora_lib zone')
    harness.assertEqual(circle:getCenter(), circleCenter, 'CircleZone should still retain the supplied center value')

    box:destroy()
    circle:destroy()
    Kora.zones.box, Kora.zones.sphere = realBox, realSphere
end)

harness.test("CircleZone with useZ=true requires true 3D proximity", function()
    local zone = CircleZone:Create({ x = 0, y = 0, z = 10 }, 3, { useZ = true, name = 'smoke-circle' })
    harness.assertTrue(zone.isCircleZone, 'circle zones must retain their upstream type marker')
    harness.assertEqual(zone.name, 'smoke-circle', 'circle zones must retain their configured name')
    harness.assertFalse(
        zone:isPointInside({ x = 0, y = 0, z = 500 }),
        "a point far away in Z must be outside when useZ=true"
    )
    harness.assertTrue(
        zone:isPointInside({ x = 0, y = 0, z = 11 }),
        "a point close on all three axes must be inside"
    )
end)

harness.test("CircleZone bakes onEnter/onExit in at creation, before :onPlayerInOut is ever called", function()
    local realSphere = Kora.zones.sphere
    local capturedOpts = nil
    Kora.zones.sphere = function(opts)
        capturedOpts = opts
        return realSphere(opts)
    end

    CircleZone:Create({ x = 0, y = 0, z = 0 }, 5, { useZ = true })

    Kora.zones.sphere = realSphere

    harness.assertTrue(type(capturedOpts.onEnter) == "function", "onEnter must be passed to Kora.zones.sphere at creation time")
    harness.assertTrue(type(capturedOpts.onExit) == "function", "onExit must be passed to Kora.zones.sphere at creation time")
end)

harness.test("CircleZone pause state suppresses its baked transition callbacks", function()
    local realSphere = Kora.zones.sphere
    local capturedOpts
    Kora.zones.sphere = function(opts)
        capturedOpts = opts
        return realSphere(opts)
    end

    local calls = 0
    local circle = CircleZone:Create({ x = 0, y = 0, z = 0 }, 5, { useZ = true })
    circle:onPlayerInOut(function() calls = calls + 1 end)
    Kora.zones.sphere = realSphere

    harness.assertFalse(circle:isPaused(), "a new circle should not start paused")
    capturedOpts.onEnter()
    circle:setPaused(true)
    capturedOpts.onExit()
    harness.assertEqual(calls, 1, "paused circles must not dispatch enter or exit callbacks")
    circle:destroy()
end)

harness.test("destroying CircleZone stops its inherited onPointInOut poll", function()
    local calls = 0
    local circle = CircleZone:Create({ x = 0, y = 0, z = 0 }, 5, {})
    circle:onPointInOut(function()
        calls = calls + 1
        return { x = 0, y = 0, z = 0 }
    end, function() end, 1)

    harness.assertEqual(calls, 1, "the inherited poll should run immediately")
    circle:destroy()
    net.step()
    harness.assertEqual(calls, 1, "destroying the circle must stop its inherited poll")
end)

harness.test("an explicit onPlayerInOut interval uses one custom poll", function()
    local circle = CircleZone:Create({ x = 0, y = 0, z = 0 }, 3, { useZ = true })
    local transitions = {}
    playerCoords = { x = 10, y = 0, z = 0 }
    circle:onPlayerInOut(function(isInside) transitions[#transitions + 1] = isInside end, 1)

    playerCoords = { x = 0, y = 0, z = 0 }
    net.step()
    net.step()
    playerCoords = { x = 10, y = 0, z = 0 }
    net.step()

    harness.assertEqual(#transitions, 2, 'an explicit interval must not duplicate kora_lib transition callbacks')
    harness.assertTrue(transitions[1] and not transitions[2], 'the custom poll should report enter then exit')
    circle:destroy()
    playerCoords = { x = 0, y = 0, z = 0 }
end)

harness.test("onPointInOut rejects malformed callbacks and wait intervals before polling", function()
    local zone = PolyZone:Create({
        vector3(-2, -2, 0), vector3(2, -2, 0), vector3(2, 2, 0), vector3(-2, 2, 0),
    }, {})

    harness.assertFalse(pcall(function() zone:onPointInOut(nil, function() end) end),
        'a missing point callback must fail synchronously')
    harness.assertFalse(pcall(function() zone:onPointInOut(function() end, nil) end),
        'a missing transition callback must fail synchronously')
    harness.assertFalse(pcall(function() zone:onPointInOut(function() end, function() end, -1) end),
        'a negative wait interval must fail synchronously')
    harness.assertFalse(pcall(function() zone:onPointInOut(function() end, function() end, math.huge) end),
        'an infinite wait interval must fail synchronously')
    zone:destroy()
end)

harness.test("CircleZone setters do not recreate a destroyed zone", function()
    local realSphere = Kora.zones.sphere
    local sphereCalls = 0
    Kora.zones.sphere = function(opts)
        sphereCalls = sphereCalls + 1
        return realSphere(opts)
    end

    local circle = CircleZone:Create({ x = 0, y = 0, z = 0 }, 5, { useZ = true })
    circle:destroy()
    circle:setRadius(10):setCenter({ x = 10, y = 0, z = 0 })
    Kora.zones.sphere = realSphere

    harness.assertEqual(sphereCalls, 1, "destroyed CircleZone setters must not allocate another kora_lib zone")
end)

harness.test("EntityZone follows moving model bounds and cleans up its player poll", function()
    local transitions = {}
    local zone = EntityZone:Create(99, { useZ = true })

    harness.assertTrue(zone:isPointInside({ x = 0, y = 0, z = 0 }), "the model's center should be inside")
    harness.assertFalse(zone:isPointInside({ x = 2, y = 0, z = 0 }), "a point outside model bounds should be outside")

    zone:onPlayerInOut(function(isInside) transitions[#transitions + 1] = isInside end, 1)
    harness.assertEqual(transitions[1], true, "the player should enter at the initial entity position")

    playerCoords = { x = 10, y = 0, z = 0 }
    net.step()
    harness.assertEqual(transitions[2], false, "moving away should exit the moving entity zone")

    entityCoords = { x = 10, y = 0, z = 0 }
    net.step()
    harness.assertEqual(transitions[3], true, "moving the entity should make the player enter again")

    trackedEntityExists = false
    net.step()
    harness.assertEqual(transitions[4], false, "deleting an entered entity should emit one final exit")
    net.step()
    harness.assertEqual(#transitions, 4, "deleting an entity must stop its player poll after the final exit")
    trackedEntityExists = true

    zone:destroy()
    net.step()
    harness.assertEqual(#transitions, 4, "destroying EntityZone must stop its player poll")
    playerCoords = { x = 0, y = 0, z = 0 }
    entityCoords = { x = 0, y = 0, z = 0 }
end)

harness.test("EntityZone rejects an invalid creation poll interval", function()
    harness.assertFalse(pcall(function() EntityZone:Create('invalid') end),
        'a non-numeric EntityZone handle must fail before entity native access')
    harness.assertFalse(pcall(function() EntityZone:Create(0) end),
        'a zero EntityZone handle must fail before entity native access')
    harness.assertFalse(pcall(function() EntityZone:Create(99, 'invalid') end),
        'a non-table EntityZone options value must fail before field access')
    harness.assertFalse(pcall(function() EntityZone:Create(99, false) end),
        'false EntityZone options must not silently become an empty table')
    harness.assertFalse(pcall(function() EntityZone:Create(99, { useZ = 'yes' }) end),
        'a non-boolean EntityZone useZ value must fail before geometry is calculated')
    harness.assertFalse(pcall(function() EntityZone:Create(99, { waitInMS = -1 }) end),
        'a negative EntityZone wait interval must fail before starting a poll')
    harness.assertFalse(pcall(function() EntityZone:Create(99, { waitInMS = 'fast' }) end),
        'a non-numeric EntityZone wait interval must fail before starting a poll')
    harness.assertFalse(pcall(function() EntityZone:Create(99, { waitInMS = math.huge }) end),
        'an infinite EntityZone wait interval must fail before starting a poll')
    harness.assertFalse(pcall(function() EntityZone:Create(99, { scale = { 1, math.huge, 1 } }) end),
        'an infinite EntityZone scale must fail before geometry is calculated')
    harness.assertFalse(pcall(function()
        EntityZone:Create(99, { scale = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, [6] = 1 } })
    end), 'a sparse EntityZone scale must fail before geometry is calculated')
    harness.assertFalse(pcall(function()
        EntityZone:Create(99, { scale = { 1, 1, -1, 1, 1, 1 } })
    end), 'EntityZone scale and offset must leave positive horizontal extents')
    harness.assertFalse(pcall(function()
        EntityZone:Create(99, { useZ = true, scale = { 1, 1, 1, 1, -1, 1 } })
    end), 'EntityZone scale and offset must leave a positive vertical extent')
    harness.assertFalse(pcall(function() EntityZone:Create(99, { offset = { 0, 0, 0, 0 } }) end),
        'a malformed EntityZone offset must fail before geometry is calculated')

    local zone = EntityZone:Create(99, {})
    harness.assertFalse(pcall(function() zone:isPointInside({ x = math.huge, y = 0, z = 0 }) end),
        'an infinite EntityZone point must fail before invoking coordinate natives')
    zone:destroy()
end)

harness.test("EntityZone damage hooks ignore malformed events and stop on destroy", function()
    local zone = EntityZone:Create(99, {})
    local calls = 0
    zone:onEntityDamaged(function(died, attacker, weapon, melee)
        calls = calls + 1
        harness.assertTrue(died and attacker == 12 and weapon == 34 and melee,
            "the damage hook should preserve the documented event fields")
    end)

    net.fire('gameEventTriggered', 'CEventNetworkEntityDamage', false)
    net.fire('gameEventTriggered', 'CEventNetworkEntityDamage', { [1] = 99, [2] = 12, [4] = 1, [5] = 34, [10] = 1 })
    zone:destroy()
    net.fire('gameEventTriggered', 'CEventNetworkEntityDamage', { [1] = 99, [2] = 12, [4] = 1, [5] = 34, [10] = 1 })

    harness.assertEqual(calls, 1, "only a valid event before destruction should reach the damage hook")
end)

harness.test("EntityZone damage callbacks are isolated and cannot be added after destroy", function()
    local zone = EntityZone:Create(99, {})
    zone:onEntityDamaged(function() error('damage callback failure') end)

    local ok = pcall(net.fire, 'gameEventTriggered', 'CEventNetworkEntityDamage',
        { [1] = 99, [2] = 12, [4] = 1, [5] = 34, [10] = 1 })
    harness.assertTrue(ok, 'a consumer damage callback must not escape the game event handler')

    zone:destroy()
    harness.assertFalse(pcall(function() zone:onEntityDamaged(function() end) end),
        'destroyed zones must reject a new inert damage handler')
end)

harness.test("EntityZone debug blips follow the entity and clean up", function()
    local zone = EntityZone:Create(99, {})
    local blip = zone:addDebugBlip()
    entityCoords = { x = 12, y = 34, z = 56 }
    net.step()

    harness.assertEqual(createdBlips[blip].x, 12, 'entity blip should follow entity X')
    harness.assertEqual(createdBlips[blip].y, 34, 'entity blip should follow entity Y')

    trackedEntityExists = false
    net.step()
    harness.assertTrue(removedBlips[blip], 'an entity disappearing must release its debug blip')
    harness.assertEqual(zone.debugBlip, nil, 'an entity disappearing must stop the per-frame blip updater')
    trackedEntityExists = true
    zone:destroy()
    harness.assertTrue(removedBlips[blip], 'destroy must release an entity debug blip')
    entityCoords = { x = 0, y = 0, z = 0 }
end)

harness.test("EntityZone draws its current bounds only when requested", function()
    local originalDrawLine, originalDrawPoly = DrawLine, DrawPoly
    local lines, walls = {}, {}
    _G.DrawLine = function(...) lines[#lines + 1] = { ... } end
    _G.DrawPoly = function(...) walls[#walls + 1] = { ... } end

    local zone = EntityZone:Create(99, { useZ = true })
    zone:draw()
    harness.assertEqual(#lines, 0, 'entity draw should require debugPoly or forceDraw')
    zone:draw(true)
    harness.assertEqual(#lines, 8, 'entity draw should render its four vertical and top edges')
    harness.assertEqual(#walls, 16, 'entity draw should render two-sided walls')
    harness.assertEqual(lines[1][3], -1, 'entity draw should use the model lower bound')
    harness.assertEqual(lines[1][6], 1, 'entity draw should use the model upper bound')

    zone:destroy()
    _G.DrawLine, _G.DrawPoly = originalDrawLine, originalDrawPoly
end)

harness.test("ComboZone delegates to its children instead of creating duplicate kora_lib zones", function()
    local realBox, realSphere = Kora.zones.box, Kora.zones.sphere
    local boxCalls, sphereCalls = 0, 0
    Kora.zones.box = function(opts) boxCalls = boxCalls + 1; return realBox(opts) end
    Kora.zones.sphere = function(opts) sphereCalls = sphereCalls + 1; return realSphere(opts) end

    local box = BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, {})
    local circle = CircleZone:Create({ x = 100, y = 100, z = 0 }, 3, { useZ = true })
    harness.assertEqual(boxCalls, 1, "sanity: BoxZone:Create makes exactly one kora_lib box")
    harness.assertEqual(sphereCalls, 1, "sanity: CircleZone:Create makes exactly one kora_lib sphere")

    local combo = ComboZone:Create({ box, circle }, {})

    Kora.zones.box, Kora.zones.sphere = realBox, realSphere

    harness.assertEqual(boxCalls, 1, "ComboZone:Create must not create a second box zone for a child that already has one")
    harness.assertEqual(sphereCalls, 1, "ComboZone:Create must not create a second sphere zone for a child that already has one")

    harness.assertTrue(combo:isPointInside({ x = 0, y = 0, z = 0 }), "combo is inside when its box child contains the point")
    harness.assertTrue(combo:isPointInside({ x = 100, y = 100, z = 0 }), "combo is inside when its circle child contains the point")
    harness.assertFalse(combo:isPointInside({ x = 9999, y = 9999, z = 0 }), "combo is outside when no child contains the point")

    -- Real PolyZone's ComboZone:onPlayerInOut calls back as
    -- (isInside, point, insideZone) -- point is the PLAYER's own position,
    -- not the child zone. Real qb-policejob's impound/garage location picker
    -- does `#(point - vector3(...))` on the 2nd argument -- passing the zone
    -- object there instead (the previous bug) broke that arithmetic outright.
    local calls = {}
    combo:onPlayerInOut(function(isInside, point, zone) calls[#calls + 1] = { isInside, point, zone } end)

    -- Prove the combo callback fired THROUGH the child's own baked-in
    -- onEnter, not through a new kora_lib zone -- box._onPlayerInOut is what
    -- ComboZone:onPlayerInOut just installed on the child. The coords box
    -- itself reports here are deliberately different from the mocked
    -- GetEntityCoords below, to prove the combo computes its own fresh point
    -- rather than forwarding whatever the child happened to pass.
    box._onPlayerInOut(true, { x = 999, y = 999, z = 999 }, box)

    harness.assertEqual(#calls, 1, "the combo's callback must fire when a child's own onPlayerInOut fires")
    harness.assertEqual(calls[1][1], true, "the forwarded isInside value must be preserved")
    harness.assertEqual(calls[1][2].x, 0, "the 2nd argument must be the player's own current position (mocked GetEntityCoords), not the child's reported coords")
    harness.assertEqual(calls[1][3], box, "the combo must identify which child changed state as the 3rd argument")
end)

harness.test('ComboZone validates child collections before a later containment call', function()
    harness.assertFalse(pcall(function() ComboZone:Create(false, {}) end))
    harness.assertFalse(pcall(function() ComboZone:Create({ false }, {}) end))
    harness.assertFalse(pcall(function() ComboZone:Create({ [2] = { isPointInside = function() end } }, {}) end))
    harness.assertFalse(pcall(function() ComboZone:Create({}, false) end))

    local empty = ComboZone:Create({}, {})
    harness.assertFalse(empty:isPointInside({ x = 0, y = 0, z = 0 }), 'empty combos remain valid and outside')
    empty:destroy()
end)

harness.test('ComboZone uses its candidate grid without excluding moving children', function()
    local calls = { near = 0, far = 0, moving = 0 }
    local near = {
        name = 'near', center = { x = 0, y = 0 }, boundingRadius = 5,
        isPointInside = function(_, point) calls.near = calls.near + 1 return point.x == 0 end,
    }
    local far = {
        name = 'far', center = { x = 3000, y = 0 }, boundingRadius = 5,
        isPointInside = function(_, point) calls.far = calls.far + 1 return point.x == 3000 end,
    }
    local moving = {
        name = 'moving',
        isPointInside = function() calls.moving = calls.moving + 1 return false end,
    }
    local combo = ComboZone:Create({ near, far, moving }, { useGrid = true })

    local nearby = combo:getZones({ x = 0, y = 0, z = 0 })
    harness.assertEqual(#nearby, 2, 'the candidate cell should contain only the nearby static zone and moving fallback')
    harness.assertEqual(nearby[1], near)
    harness.assertEqual(nearby[2], moving)
    harness.assertTrue(combo:isPointInside({ x = 0, y = 0, z = 0 }))
    harness.assertEqual(calls.near, 1)
    harness.assertEqual(calls.far, 0, 'distant static children must not be tested')
    harness.assertEqual(calls.moving, 0, 'a matching indexed child should avoid unnecessary fallback checks')

    combo:RemoveZone('near')
    harness.assertFalse(combo:isPointInside({ x = 0, y = 0, z = 0 }))
    harness.assertEqual(calls.far, 0, 'removing a child must rebuild the candidate grid')
    harness.assertEqual(calls.moving, 1, 'moving children remain checked after a static child is removed')
    combo:destroy()
end)

harness.test('ComboZone keeps map-spanning static children out of the reference grid', function()
    local spanning = {
        name = 'spanning', center = { x = 0, y = 0 }, boundingRadius = 10000,
        isPointInside = function(_, point) return point.x == 9000 end,
    }
    local combo = ComboZone:Create({ spanning }, { useGrid = true })

    harness.assertEqual(combo.unindexedZones[1], spanning)
    harness.assertEqual(next(combo.grid), nil, 'a map-spanning child must not allocate out-of-map grid cells')
    harness.assertTrue(combo:isPointInside({ x = 9000, y = 0, z = 0 }),
        'the fallback child must remain queryable outside the static grid bounds')
    combo:destroy()
end)

harness.test('ComboZone refreshes static candidates when a child zone changes geometry', function()
    local box = BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, {})
    local circle = CircleZone:Create({ x = 1000, y = 100, z = 0 }, 2, {})
    local combo = ComboZone:Create({ box, circle }, { useGrid = true })

    box:setCenter({ x = 3000, y = 0, z = 0 })
    circle:setRadius(250)
    harness.assertFalse(combo:isPointInside({ x = 0, y = 0, z = 0 }), 'the old box cell must no longer contain the moved child')
    harness.assertTrue(combo:isPointInside({ x = 3000, y = 0, z = 0 }), 'the new box cell must contain the moved child')
    harness.assertTrue(combo:isPointInside({ x = 1200, y = 100, z = 500 }), 'the resized flat circle must refresh its candidate bounds')
    combo:destroy()
end)

harness.test("ComboZone reports combined transitions across overlapping children", function()
    local first = BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, {})
    local second = BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, {})
    local combo = ComboZone:Create({ first, second }, {})
    local transitions = {}
    combo:onPlayerInOut(function(isInside) transitions[#transitions + 1] = isInside end)

    first._onPlayerInOut(true)
    second._onPlayerInOut(true)
    first._onPlayerInOut(false)
    harness.assertEqual(#transitions, 1, "entering or leaving an overlapping child must not duplicate combined state")
    second._onPlayerInOut(false)

    harness.assertEqual(transitions[1], true, "the first child entry should enter the combo")
    harness.assertEqual(transitions[2], false, "leaving the final child should exit the combo")
    combo:destroy()
end)

harness.test("ComboZone supports dynamic membership without extra kora_lib zones", function()
    local first = BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, { name = 'first' })
    local second = BoxZone:Create({ x = 10, y = 0, z = 0 }, 4, 4, { name = 'second' })
    local combo = ComboZone:Create({ first }, { name = 'all' })
    local callbacks = 0
    combo:onPlayerInOut(function() callbacks = callbacks + 1 end)

    combo:AddZone(second)
    harness.assertTrue(combo.isComboZone and combo.useGrid, 'combo type markers should match PolyZone')
    harness.assertEqual(#combo:getZones({ x = 0, y = 0, z = 0 }), 2, 'getZones should include dynamically added children')
    harness.assertTrue(combo:isPointInside({ x = 10, y = 0, z = 0 }), 'added child should contribute containment')
    local isInside, inside = combo:isPointInsideExhaustive({ x = 0, y = 0, z = 0 })
    harness.assertTrue(isInside and inside[1] == first, 'exhaustive containment should return matching children')

    local removed = combo:RemoveZone('second')
    second._onPlayerInOut(true)
    harness.assertEqual(removed, second, 'RemoveZone should return the removed child')
    harness.assertEqual(callbacks, 0, 'removed children must no longer drive combo callbacks')
    harness.assertFalse(combo:isPointInside({ x = 10, y = 0, z = 0 }), 'removed child should no longer contribute containment')
    combo:destroy()
    second:destroy()
end)

harness.test("ComboZone exhaustive polling reports changed child membership", function()
    local first = BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, {})
    local second = BoxZone:Create({ x = 10, y = 0, z = 0 }, 4, 4, {})
    local combo = ComboZone:Create({ first, second }, {})
    local point = { x = 100, y = 0, z = 0 }
    local calls = {}

    combo:onPointInOutExhaustive(function() return point end, function(isInside, _, inside, entered, left)
        calls[#calls + 1] = { isInside = isInside, inside = inside, entered = entered, left = left }
    end, 1)
    point = { x = 0, y = 0, z = 0 }
    net.step()
    point = { x = 10, y = 0, z = 0 }
    net.step()
    point = { x = 100, y = 0, z = 0 }
    net.step()

    harness.assertEqual(#calls, 4, 'initial state and each membership change should report once')
    harness.assertFalse(calls[1].isInside, 'the initial outside state should be reported')
    harness.assertTrue(calls[2].entered[1] == first, 'entering the first child should identify it')
    harness.assertTrue(calls[3].entered[1] == second and calls[3].left[1] == first,
        'moving between children should report both membership changes')
    harness.assertTrue(calls[4].left[1] == second, 'leaving the final child should identify it')
    combo:destroy()
end)

harness.test("ComboZone honors explicit onPlayerInOut timing with its child argument", function()
    local first = BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, {})
    local combo = ComboZone:Create({ first }, {})
    local calls = {}
    playerCoords = { x = 10, y = 0, z = 0 }
    combo:onPlayerInOut(function(isInside, _, zone) calls[#calls + 1] = { isInside, zone } end, 1)

    playerCoords = { x = 0, y = 0, z = 0 }
    net.step()
    playerCoords = { x = 10, y = 0, z = 0 }
    net.step()

    harness.assertEqual(#calls, 2, 'the explicit poll should report enter and exit once')
    harness.assertTrue(calls[1][1] and not calls[2][1], 'the custom combo poll should preserve transitions')
    harness.assertEqual(calls[1][2], first, 'entry should identify the child that contains the player')
    harness.assertEqual(calls[2][2], first, 'exit should retain the previously entered child')
    combo:destroy()
    playerCoords = { x = 0, y = 0, z = 0 }
end)

harness.test("ComboZone addEvent can filter to one named child", function()
    local first = BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, { name = 'first' })
    local second = BoxZone:Create({ x = 10, y = 0, z = 0 }, 4, 4, { name = 'second' })
    local combo = ComboZone:Create({ first, second }, {})
    local calls = 0
    AddEventHandler('smoke:combo-event', function() calls = calls + 1 end)

    combo:addEvent('smoke:combo-event', 'second')
    net.fire('__PolyZone__:smoke:combo-event')
    playerCoords = { x = 10, y = 0, z = 0 }
    net.fire('__PolyZone__:smoke:combo-event')
    playerCoords = { x = 0, y = 0, z = 0 }

    harness.assertEqual(calls, 1, 'the optional name must suppress events from other combo children')
    combo:destroy()
end)

harness.test("ComboZone debug blips delegate to children", function()
    local first = BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, {})
    local second = CircleZone:Create({ x = 10, y = 0, z = 0 }, 2, {})
    local combo = ComboZone:Create({ first, second }, {})
    local blips = combo:addDebugBlip()

    harness.assertEqual(#blips, 2, 'combo debug helpers should create one blip per child')
    combo:destroy()
    harness.assertTrue(removedBlips[blips[1]] and removedBlips[blips[2]],
        'destroying a combo must release child debug blips')
end)

harness.test("ComboZone draw delegates only to live child zones", function()
    local firstCalls = 0
    local first = {
        destroyed = false,
        isPointInside = function() return false end,
        draw = function(_, forceDraw) firstCalls = firstCalls + (forceDraw and 1 or 10) end,
    }
    local second = {
        destroyed = true,
        isPointInside = function() return false end,
        draw = function() error('destroyed child should not draw') end,
    }
    local combo = ComboZone:Create({ first, second }, {})

    combo:draw(true)
    harness.assertEqual(firstCalls, 1, 'combo draw should forward forceDraw to live children')
    combo:destroy()
    combo:draw(true)
    harness.assertEqual(firstCalls, 1, 'destroyed combos should not draw children')
end)

harness.test("ComboZone printInfo retains the legacy zone summary", function()
    local originalPrint = print
    local output = {}
    _G.print = function(message) output[#output + 1] = message end

    local combo = ComboZone:Create({
        { isBoxZone = true, isPointInside = function() return false end },
        { isCircleZone = true, isPointInside = function() return false end },
        { isEntityZone = true, isPointInside = function() return false end },
    }, { name = 'summary' })
    combo:printInfo()
    _G.print = originalPrint

    harness.assertEqual(output[2], '[PolyZone] Info for ComboZone { name = "summary" }:', 'summary should include the combo name')
    harness.assertEqual(output[3], '[PolyZone]   Total zones: 3', 'summary should include child count')
    harness.assertTrue(output[4]:find('BoxZones: 1', 1, true) ~= nil, 'summary should count box children')
    harness.assertTrue(output[5]:find('CircleZones: 1', 1, true) ~= nil, 'summary should count circle children')
    harness.assertTrue(output[6]:find('EntityZones: 1', 1, true) ~= nil, 'summary should count entity children')
end)

harness.test("removing a zone through the handle does not error (dot-call, not colon-call)", function()
    local box = BoxZone:Create({ x = 0, y = 0, z = 0 }, 4, 4, {})
    harness.assertTrue(pcall(function() box:destroy() end), "BoxZone:destroy must not error calling the handle's remove")

    local circle = CircleZone:Create({ x = 0, y = 0, z = 0 }, 3, {})
    harness.assertTrue(pcall(function() circle:destroy() end), "CircleZone:destroy must not error calling the handle's remove")

    local poly = PolyZone:Create({ { x = 0, y = 0 }, { x = 5, y = 0 }, { x = 5, y = 5 } }, {})
    harness.assertTrue(pcall(function() poly:destroy() end), "PolyZone:destroy must not error calling the handle's remove")
end)

harness.report("PolyZone backward-compat shim")
