CircleZone = {}

setmetatable(CircleZone, {
    __index = PolyZone
})

-- Vanilla PolyZone's CircleZone, when useZ is false (the default), is a pure
-- 2D radial test. kora_lib's native circle has that same exact boundary and
-- shares the normal zone grid; useZ=true retains the 3D sphere behavior.

local function assertCenter(center)
    local centerType = type(center)
    assert((centerType == 'table' or centerType == 'vector3') and Kora.util.isFiniteNumber(center.x) and Kora.util.isFiniteNumber(center.y)
        and Kora.util.isFiniteNumber(center.z), 'center must have finite x, y, and z coordinates')
end

local function sameCoords(left, right)
    return left.x == right.x and left.y == right.y and left.z == right.z
end

-- Bakes onEnter/onExit in at creation time (matching BoxZone/PolyZone)
-- instead of only after :onPlayerInOut() is called -- a consumer that reads
-- isPointInside only, or assigns _onPlayerInOut directly, previously got a
-- permanently silent zone. Shared by Create/onPlayerInOut/setRadius/
-- setCenter so every rebuild goes through one place.
local function buildQbZone(self)
    local onEnter = function()
        if self.destroyed or self.paused then return end
        if self._onPlayerInOut then self._onPlayerInOut(true) end
    end

    local onExit = function()
        if self.destroyed or self.paused then return end
        if self._onPlayerInOut then self._onPlayerInOut(false) end
    end

    if self.useZ then
        return Kora.zones.sphere({
            coords = self.center,
            radius = self.radius,
            includeBoundary = false,
            debug = self.debugPoly,
            onEnter = onEnter,
            onExit = onExit,
        })
    end

    return Kora.zones.circle({
        coords = self.center,
        radius = self.radius,
        includeBoundary = false,
        debug = self.debugPoly,
        onEnter = onEnter,
        onExit = onExit,
    })
end

local function refreshComboGrids(object)
    for combo, refresh in pairs(object._comboGridListeners or {}) do
        if combo.destroyed then
            object._comboGridListeners[combo] = nil
        else
            refresh()
        end
    end
end

function CircleZone:Create(center, radius, options)
    assertCenter(center)
    assert(Kora.util.isFiniteNumber(radius) and radius > 0, 'radius must be a positive finite number')
    if options == nil then options = {} end
    assert(type(options) == 'table', 'CircleZone options must be a table')
    assert(options.useZ == nil or type(options.useZ) == 'boolean', 'CircleZone useZ must be a boolean')
    assert(options.debugPoly == nil or type(options.debugPoly) == 'boolean', 'CircleZone debugPoly must be a boolean')
    assert(options.debugBlip == nil or type(options.debugBlip) == 'boolean', 'CircleZone debugBlip must be a boolean')

    local object = setmetatable({
        type = 'sphere',
        center = center,
        radius = radius + 0.0,
        diameter = radius * 2.0,
        name = options.name,
        isCircleZone = true,

        useZ = options.useZ or false,
        debugPoly = options.debugPoly or false,
        debugColor = options.debugColor or { 0, 255, 0 },
        data = options.data or {},

        _onPlayerInOut = nil,
        _qbZone = nil,
        destroyed = false,
        paused = false,
    }, {
        __index = CircleZone
    })

    object._qbZone = buildQbZone(object)
    if options.debugBlip then object:addDebugBlip() end

    return object
end

function CircleZone:new(center, radius, options)
    return CircleZone:Create(center, radius, options)
end

function CircleZone:onPlayerInOut(callback, waitInMS)
    return PolyZone.onPlayerInOut(self, callback, waitInMS)
end

function CircleZone:draw(forceDraw)
    if self.destroyed or (not forceDraw and not self.debugPoly) then
        return
    end

    local color = self.debugColor

    if self.useZ then
        DrawMarker(28, self.center.x, self.center.y, self.center.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            self.radius, self.radius, self.radius, color[1], color[2], color[3], 48, false, false, 2, nil, nil, false)
        return
    end

    DrawMarker(1, self.center.x, self.center.y, -500.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        self.diameter, self.diameter, 1000.0, color[1], color[2], color[3], 96, false, false, 2, nil, nil, false)
end

function CircleZone:isPointInside(point)
    if self.destroyed or not self._qbZone then
        return false
    end
    return self._qbZone.contains(point)
end

function CircleZone:getRadius()
    return self.radius
end

function CircleZone:setRadius(radius)
    assert(Kora.util.isFiniteNumber(radius) and radius > 0, "radius must be a positive finite number")

    if self.destroyed or radius == self.radius then return self end
    self.radius = radius
    self.diameter = radius * 2.0

    if self._qbZone then
        self._qbZone.remove()
    end

    self._qbZone = buildQbZone(self)
    refreshComboGrids(self)

    return self
end

function CircleZone:getCenter()
    return self.center
end

function CircleZone:setCenter(center)
    assertCenter(center)
    if self.destroyed then return self end
    local unchanged = sameCoords(center, self.center)
    self.center = center
    if unchanged then return self end

    if self._qbZone then
        self._qbZone.remove()
    end

    self._qbZone = buildQbZone(self)
    refreshComboGrids(self)

    return self
end

function CircleZone:destroy()
    if self.destroyed then
        return
    end
    self.destroyed = true

    if self._qbZone then
        self._qbZone.remove()
        self._qbZone = nil
    end

    for eventName in pairs(self.events or {}) do
        self:removeEvent(eventName)
    end
    self:removeDebugBlip()
end

function CircleZone:remove()
    self:destroy()
end

return CircleZone
