BoxZone = {}

setmetatable(BoxZone, {
    __index = PolyZone
})


local function expandBounds(values, default, label)
    values = values or { default, default, default }
    assert(type(values) == 'table', ('BoxZone %s must be an array.'):format(label))
    local count = 0
    for index in pairs(values) do
        assert(Kora.util.isInteger(index) and index >= 1, ('BoxZone %s must be a dense array.'):format(label))
        count = count + 1
    end
    assert((count == 3 or count == 6) and count == #values,
        ('BoxZone %s must contain 3 or 6 finite values.'):format(label))
    for index = 1, count do
        assert(Kora.util.isFiniteNumber(values[index]), ('BoxZone %s values must be finite numbers.'):format(label))
    end
    if count == 3 then
        return { values[1], values[1], values[2], values[2], values[3], values[3] }
    end
    return values
end

local function assertCoords(coords)
    local coordsType = type(coords)
    assert((coordsType == 'table' or coordsType == 'vector3') and Kora.util.isFiniteNumber(coords.x)
        and Kora.util.isFiniteNumber(coords.y) and Kora.util.isFiniteNumber(coords.z),
        'center must have finite x, y, and z coordinates')
end

local function sameCoords(left, right)
    return left.x == right.x and left.y == right.y and left.z == right.z
end

function BoxZone.calculateMinAndMaxZ(minZ, maxZ, scaleZ, offsetZ)
    scaleZ = scaleZ or { 1.0, 1.0 }
    offsetZ = offsetZ or { 0.0, 0.0 }
    local minScale, maxScale = scaleZ[1] or 1.0, scaleZ[2] or 1.0
    local minOffset, maxOffset = offsetZ[1] or 0.0, offsetZ[2] or 0.0

    if minZ and maxZ and (minScale ~= 1.0 or maxScale ~= 1.0) then
        local center = (minZ + maxZ) / 2
        local halfHeight = (maxZ - minZ) / 2
        minZ = center - halfHeight * minScale
        maxZ = center + halfHeight * maxScale
    end

    if minZ then minZ = minZ - minOffset end
    if maxZ then maxZ = maxZ + maxOffset end
    return minZ, maxZ
end

local function resolveGeometry(object)
    local scale, offset = object.scale, object.offset
    local minX = -object.width / 2 * scale[3] - offset[3]
    local maxX = object.width / 2 * scale[4] + offset[4]
    local minY = -object.length / 2 * scale[2] - offset[2]
    local maxY = object.length / 2 * scale[1] + offset[1]
    local middleX, middleY = (minX + maxX) / 2, (minY + maxY) / 2
    local radians = math.rad(object.heading)
    local cosine, sine = math.cos(radians), math.sin(radians)
    local minZ, maxZ = object.options.minZ, object.options.maxZ

    if minZ and maxZ then
        local middleZ = (minZ + maxZ) / 2
        local halfHeight = (maxZ - minZ) / 2
        minZ = middleZ - halfHeight * scale[6] - offset[6]
        maxZ = middleZ + halfHeight * scale[5] + offset[5]
    else
        minZ, maxZ = object.coords.z - 1.5, object.coords.z + 1.5
    end

    assert(maxX > minX and maxY > minY and maxZ > minZ,
        'BoxZone scale and offset must leave positive extents on every axis')

    local center = vector3(
        object.coords.x + middleX * cosine - middleY * sine,
        object.coords.y + middleX * sine + middleY * cosine,
        (minZ + maxZ) / 2
    )
    local size = vector3(maxX - minX, maxY - minY, maxZ - minZ)
    return center, size, minZ, maxZ, {
        vector3(object.coords.x + minX, object.coords.y + minY, center.z),
        vector3(object.coords.x + maxX, object.coords.y + minY, center.z),
        vector3(object.coords.x + maxX, object.coords.y + maxY, center.z),
        vector3(object.coords.x + minX, object.coords.y + maxY, center.z),
    }
end

local function buildQbZone(object)
    local coords, size, minZ, maxZ, points = resolveGeometry(object)
    object.center, object.minZ, object.maxZ = coords, minZ, maxZ
    object.points = points
    object.boundingRadius = math.sqrt(size.x * size.x + size.y * size.y) / 2

    return Kora.zones.box({
        coords = coords,
        size = size,
        rotation = -object.heading,
        ignoreZ = object.options.minZ == nil,
        debug = object.debugPoly,
        onEnter = function()
            if object.destroyed or object.paused then return end
            if object._onPlayerInOut then
                object._onPlayerInOut(true, GetEntityCoords(PlayerPedId()), object)
            end
        end,
        onExit = function()
            if object.destroyed or object.paused then return end
            if object._onPlayerInOut then
                object._onPlayerInOut(false, GetEntityCoords(PlayerPedId()), object)
            end
        end,
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

local function rebuild(self)
    if self.destroyed then return end
    self._qbZone.remove()
    self._qbZone = buildQbZone(self)
    refreshComboGrids(self)
end

function BoxZone:Create(coords, length, width, options)
    assertCoords(coords)
    assert(Kora.util.isFiniteNumber(length) and length > 0, 'length must be a positive finite number')
    assert(Kora.util.isFiniteNumber(width) and width > 0, 'width must be a positive finite number')
    if options == nil then options = {} end
    assert(type(options) == 'table', 'BoxZone options must be a table')
    assert(options.heading == nil or Kora.util.isFiniteNumber(options.heading), 'BoxZone heading must be finite')
    assert(options.debugPoly == nil or type(options.debugPoly) == 'boolean', 'BoxZone debugPoly must be a boolean')
    assert(options.debugBlip == nil or type(options.debugBlip) == 'boolean', 'BoxZone debugBlip must be a boolean')
    assert((options.minZ == nil) == (options.maxZ == nil), 'BoxZone minZ and maxZ must be supplied together')
    assert(options.minZ == nil or Kora.util.isFiniteNumber(options.minZ), 'BoxZone minZ must be finite')
    assert(options.maxZ == nil or Kora.util.isFiniteNumber(options.maxZ), 'BoxZone maxZ must be finite')
    assert(options.minZ == nil or options.maxZ > options.minZ, 'BoxZone maxZ must exceed minZ')


    local object = setmetatable({
        type = 'box',

        coords = coords,
        length = length,
        width = width,
        heading = options.heading or 0.0,
        isBoxZone = true,
        scale = expandBounds(options.scale, 1.0, 'scale'),
        offset = expandBounds(options.offset, 0.0, 'offset'),

        options = options,

        name = options.name,
        data = options.data or {},

        debugPoly = options.debugPoly or false,
        debugColors = options.debugColors or {},

        destroyed = false,
        paused = false,

        _onPlayerInOut = nil,
        _qbZone = nil,
    }, {
        __index = BoxZone
    })

    object._qbZone = buildQbZone(object)
    if options.debugBlip then object:addDebugBlip() end

    return object
end

function BoxZone:new(coords, length, width, options)
    return BoxZone:Create(coords, length, width, options)
end

function BoxZone:onPlayerInOut(callback, waitInMS)
    return PolyZone.onPlayerInOut(self, callback, waitInMS)
end

function BoxZone:TransformPoint(point)
    local rotated = PolyZone.rotate(self.coords, point, self.heading)
    return vector3(rotated.x, rotated.y, point.z)
end

function BoxZone:isPointInside(point)
    if self.destroyed then
        return false
    end

    if not self._qbZone then
        return false
    end

    return self._qbZone.contains(point)
end

function BoxZone:getHeading()
    return self.heading
end

function BoxZone:setHeading(heading)
    assert(Kora.util.isFiniteNumber(heading), 'heading must be a finite number')
    if heading == self.heading then return self end
    self.heading = heading
    rebuild(self)
    return self
end

function BoxZone:getCenter()
    return self.coords
end

function BoxZone:setCenter(coords)
    assertCoords(coords)
    local unchanged = sameCoords(coords, self.coords)
    self.coords = coords
    if not unchanged then rebuild(self) end
    return self
end

function BoxZone:getLength()
    return self.length
end

function BoxZone:setLength(length)
    assert(Kora.util.isFiniteNumber(length) and length > 0, 'length must be a positive finite number')
    if length == self.length then return self end
    self.length = length
    rebuild(self)
    return self
end

function BoxZone:getWidth()
    return self.width
end

function BoxZone:setWidth(width)
    assert(Kora.util.isFiniteNumber(width) and width > 0, 'width must be a positive finite number')
    if width == self.width then return self end
    self.width = width
    rebuild(self)
    return self
end

function BoxZone:destroy()
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

function BoxZone:remove()
    self:destroy()
end

function BoxZone:setPaused(paused)
    self.paused = paused
end

function BoxZone:isPaused()
    return self.paused
end

return BoxZone
