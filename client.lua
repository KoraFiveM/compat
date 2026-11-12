-- PolyZone.lua
--
-- Vanilla PolyZone consumers @-import this file (and the other zone files)
-- straight into THEIR OWN resource VM via `client_scripts '@PolyZone/...'`.
-- This shim delegates to Kora.zones.*, and the Kora proxy global is per-VM --
-- PolyZone's own manifest only loads @kora_lib/init.lua into PolyZone's VM, and
-- a legacy consumer's manifest (which we cannot edit) won't include it. So
-- bootstrap Kora here when it's absent, same forwarder pattern as
-- kora_sql/stubs/oxmysql/lib/MySQL.lua: kora_lib lists init.lua under files{}
-- precisely so any VM (client included) can fetch and run it.
if Kora == nil then
    local chunk = LoadResourceFile('kora_lib', 'init.lua')
    assert(chunk, '[PolyZone] could not read kora_lib/init.lua -- is the kora_lib resource started?')
    assert(load(chunk, '@kora_lib/init.lua'))()
end

PolyZone = {}

local DEFAULT_OUTLINE_COLOR = { 255, 0, 0 }
local DEFAULT_WALL_COLOR = { 0, 255, 0 }


local function ensureVec3(point)
    if point.x and point.y then
        return vector3(
            point.x,
            point.y,
            point.z or 0.0
        )
    end

    return point
end

local function ensurePoints(points)
    local converted = {}

    for i = 1, #points do
        converted[i] = ensureVec3(points[i])
    end

    return converted
end

local function assertPoints(points)
    assert(type(points) == 'table', 'PolyZone points must be an array.')
    local count = 0
    for index, point in pairs(points) do
        local pointType = type(point)
        assert(Kora.util.isInteger(index) and index >= 1 and (pointType == 'table' or pointType == 'vector2' or pointType == 'vector3')
            and Kora.util.isFiniteNumber(point.x) and Kora.util.isFiniteNumber(point.y)
            and (point.z == nil or Kora.util.isFiniteNumber(point.z)),
            'PolyZone points must be a dense array of finite 2D or 3D coordinates.')
        count = count + 1
    end
    assert(count >= 3 and count == #points, 'PolyZone requires at least 3 dense points.')
end

local function calculateBounds(points)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local area = 0.0

    for i = 1, #points do
        local point = points[i]
        local nextPoint = points[i % #points + 1]
        minX = math.min(minX, point.x)
        minY = math.min(minY, point.y)
        maxX = math.max(maxX, point.x)
        maxY = math.max(maxY, point.y)
        area = area + point.x * nextPoint.y - nextPoint.x * point.y
    end

    local minimum = vector2(minX, minY)
    local maximum = vector2(maxX, maxY)
    local size = vector2(maxX - minX, maxY - minY)

    return minimum, maximum, size, vector2((minX + maxX) / 2.0, (minY + maxY) / 2.0), math.abs(area) / 2.0
end

local function createDebugBlip(coords)
    local blip = AddBlipForCoord(coords.x, coords.y, 0.0)
    SetBlipColour(blip, 7)
    SetBlipDisplay(blip, 8)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, true)
    return blip
end

function PolyZone.rotate(origin, point, theta)
    local originType, pointType = type(origin), type(point)
    assert((originType == 'table' or originType == 'vector2' or originType == 'vector3')
        and Kora.util.isFiniteNumber(origin.x) and Kora.util.isFiniteNumber(origin.y),
        'origin must have finite x and y coordinates')
    assert((pointType == 'table' or pointType == 'vector2' or pointType == 'vector3')
        and Kora.util.isFiniteNumber(point.x) and Kora.util.isFiniteNumber(point.y),
        'point must have finite x and y coordinates')
    assert(Kora.util.isFiniteNumber(theta), 'theta must be a finite number')
    if theta == 0 then return point end

    local radians = math.rad(theta)
    local cosine, sine = math.cos(radians), math.sin(radians)
    local x, y = point.x - origin.x, point.y - origin.y

    return vector2(x * cosine - y * sine + origin.x, x * sine + y * cosine + origin.y)
end

function PolyZone:Create(points, options)
    assertPoints(points)
    if options == nil then options = {} end
    assert(type(options) == 'table', 'PolyZone options must be a table.')
    assert(options.debugPoly == nil or type(options.debugPoly) == 'boolean', 'PolyZone debugPoly must be a boolean.')
    assert(options.debugGrid == nil or type(options.debugGrid) == 'boolean', 'PolyZone debugGrid must be a boolean.')
    assert(options.debugBlip == nil or type(options.debugBlip) == 'boolean', 'PolyZone debugBlip must be a boolean.')
    assert(options.minZ == nil or Kora.util.isFiniteNumber(options.minZ), 'PolyZone minZ must be finite.')
    assert(options.maxZ == nil or Kora.util.isFiniteNumber(options.maxZ), 'PolyZone maxZ must be finite.')
    assert((options.minZ == nil) == (options.maxZ == nil), 'PolyZone minZ and maxZ must be supplied together.')
    assert(options.minZ == nil or options.maxZ > options.minZ, 'PolyZone maxZ must exceed minZ.')
    assert(options.thickness == nil or (Kora.util.isFiniteNumber(options.thickness) and options.thickness > 0),
        'PolyZone thickness must be a positive finite number.')
    local convertedPoints = ensurePoints(points)
    local minimum, maximum, size, center, area = calculateBounds(convertedPoints)

    local object = setmetatable({
        type = 'poly',

        points = convertedPoints,
        name = options.name,
        min = minimum,
        max = maximum,
        size = size,
        center = center,
        area = area,
        boundingRadius = math.sqrt(size.x * size.x + size.y * size.y) / 2.0,
        isPolyZone = true,

        minZ = options.minZ,
        maxZ = options.maxZ,

        debugPoly = options.debugPoly or false,
        debugGrid = options.debugGrid or false,
        debugColors = options.debugColors or {},
        data = options.data or {},

        useGrid = options.useGrid ~= false,
        lazyGrid = options.lazyGrid ~= false,

        _onPlayerInOut = nil,
        _qbZone = nil,

        destroyed = false,
        paused = false,
    }, {
        __index = PolyZone
    })

    local thickness = options.thickness

    if options.minZ and options.maxZ then
        thickness = options.maxZ - options.minZ
    end

    thickness = thickness or 1.0

    local qbOpts = {
        points = object.points,
        thickness = thickness,
        -- Legacy PolyZone consumers pass 2D points plus explicit minZ/maxZ --
        -- points here are flattened to z=0 by ensureVec3 above, so without
        -- forwarding these kora_lib anchors the height band at 0..thickness and
        -- a player at any real elevation is never inside (onEnter never
        -- fires). Only meaningful together; kora_lib itself asserts that.
        minZ = options.minZ,
        maxZ = options.maxZ,
        -- Upstream only applies vertical containment when both bounds are
        -- supplied. Keep that exact 2D behavior without a huge fake height.
        ignoreZ = options.minZ == nil,
        debug = object.debugPoly or object.debugGrid,

        onEnter = function()
            if object.destroyed or object.paused then
                return
            end

            if object._onPlayerInOut then
                object._onPlayerInOut(
                    true,
                    GetEntityCoords(PlayerPedId())
                )
            end
        end,

        onExit = function()
            if object.destroyed or object.paused then
                return
            end

            if object._onPlayerInOut then
                object._onPlayerInOut(
                    false,
                    GetEntityCoords(PlayerPedId())
                )
            end
        end,
    }

    object._qbZone = Kora.zones.poly(qbOpts)
    if options.debugBlip then object:addDebugBlip() end

    return object
end

function PolyZone:new(points, options)
    return PolyZone:Create(points, options)
end

function PolyZone:isPointInside(point)
    if self.destroyed then
        return false
    end

    if not self._qbZone then
        return false
    end

    return self._qbZone.contains(ensureVec3(point))
end

function PolyZone:onPlayerInOut(callback, waitInMS)
    assert(type(callback) == 'function', 'callback must be a function')
    assert(waitInMS == nil or (Kora.util.isFiniteNumber(waitInMS) and waitInMS >= 0),
        'waitInMS must be a non-negative number')

    self._playerPollId = (self._playerPollId or 0) + 1
    if waitInMS == nil then
        self._onPlayerInOut = callback
        return self
    end

    self._onPlayerInOut = nil
    local pollId = self._playerPollId

    CreateThread(function()
        local isInside = false

        while not self.destroyed and self._playerPollId == pollId do
            if not self.paused then
                local point = PolyZone.getPlayerPosition()
                local newIsInside = self:isPointInside(point)

                if newIsInside ~= isInside then
                    callback(newIsInside, point, self)
                    isInside = newIsInside
                end
            end

            Wait(waitInMS)
        end
    end)

    return self
end
function PolyZone:onPointInOut(getPointCb, onPointInOutCb, waitInMS)
    assert(type(getPointCb) == 'function', 'getPointCb must be a function')
    assert(type(onPointInOutCb) == 'function', 'onPointInOutCb must be a function')
    assert(waitInMS == nil or (Kora.util.isFiniteNumber(waitInMS) and waitInMS >= 0),
        'waitInMS must be a non-negative number')

    local waitTime = waitInMS or 500

    CreateThread(function()
        local isInside = false

        while not self.destroyed do
            if not self.paused then
                local point = getPointCb()
                local newIsInside = self:isPointInside(point)

                if newIsInside ~= isInside then
                    onPointInOutCb(newIsInside, point)
                    isInside = newIsInside
                end
            end

            Wait(waitTime)
        end
    end)
end

function PolyZone:destroy()
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

function PolyZone:TransformPoint(point)
    return point
end

local function drawWall(first, second, minZ, maxZ, color)
    DrawPoly(first.x, first.y, minZ, first.x, first.y, maxZ, second.x, second.y, minZ,
        color[1], color[2], color[3], 48)
    DrawPoly(first.x, first.y, maxZ, second.x, second.y, maxZ, second.x, second.y, minZ,
        color[1], color[2], color[3], 48)
    DrawPoly(second.x, second.y, minZ, second.x, second.y, maxZ, first.x, first.y, maxZ,
        color[1], color[2], color[3], 48)
    DrawPoly(second.x, second.y, minZ, first.x, first.y, maxZ, first.x, first.y, minZ,
        color[1], color[2], color[3], 48)
end

function PolyZone:draw(forceDraw)
    if self.destroyed or (not forceDraw and not self.debugPoly and not self.debugGrid) then
        return
    end

    local position = GetEntityCoords(PlayerPedId())
    local minZ = self.minZ or position.z - 45.0
    local maxZ = self.maxZ or position.z + 45.0
    local debugColors = self.debugColors or {}
    local outline = debugColors.outline or DEFAULT_OUTLINE_COLOR
    local walls = debugColors.walls or DEFAULT_WALL_COLOR
    local points = self.points

    for i = 1, #points do
        local first = self:TransformPoint(points[i])
        local second = self:TransformPoint(points[i % #points + 1])

        DrawLine(first.x, first.y, minZ, first.x, first.y, maxZ, outline[1], outline[2], outline[3], 164)
        DrawLine(first.x, first.y, maxZ, second.x, second.y, maxZ, outline[1], outline[2], outline[3], 184)
        drawWall(first, second, minZ, maxZ, walls)
    end
end

function PolyZone.drawPoly(zone, forceDraw)
    return PolyZone.draw(zone, forceDraw)
end

function PolyZone:getBoundingBoxMin()
    return self.min
end

function PolyZone:getBoundingBoxMax()
    return self.max
end

function PolyZone:getBoundingBoxSize()
    return self.size
end

function PolyZone:getBoundingBoxCenter()
    return self.center
end

function PolyZone:addDebugBlip()
    local coords = self.center or self.coords or self:getBoundingBoxCenter()
    assert(coords, 'zone does not have a center for a debug blip')
    self:removeDebugBlip()
    self.debugBlip = createDebugBlip(coords)
    return self.debugBlip
end

function PolyZone:removeDebugBlip()
    if not self.debugBlip then return end
    RemoveBlip(self.debugBlip)
    self.debugBlip = nil
end

function PolyZone:remove()
    self:destroy()
end

function PolyZone:setPaused(paused)
    self.paused = paused
end

function PolyZone:isPaused()
    return self.paused
end

function PolyZone.getPlayerPosition()
    local ped = PlayerPedId()

    if not DoesEntityExist(ped) then
        return vector3(0.0, 0.0, 0.0)
    end

    return GetEntityCoords(ped)
end

function PolyZone.getPlayerHeadPosition()
    local ped = PlayerPedId()

    if not DoesEntityExist(ped) then
        return vector3(0.0, 0.0, 0.0)
    end

    return GetPedBoneCoords(ped, 0x796e)
end

function PolyZone.ensureMetatable(zone)
    if type(zone) ~= 'table' then return zone end

    local class = zone.isComboZone and ComboZone
        or zone.isEntityZone and EntityZone
        or zone.isBoxZone and BoxZone
        or zone.isCircleZone and CircleZone
        or zone.isPolyZone and PolyZone

    if class then
        setmetatable(zone, { __index = class })
    end

    return zone
end

function PolyZone:addEvent(eventName, zoneName)
    assert(type(eventName) == 'string' and eventName ~= '', 'eventName must be a non-empty string')
    assert(zoneName == nil or (type(zoneName) == 'string' and zoneName ~= ''), 'zoneName must be a non-empty string or nil')
    self:removeEvent(eventName)
    self.events = self.events or {}

    local internalEvent = '__PolyZone__:' .. eventName
    RegisterNetEvent(internalEvent)
    self.events[eventName] = AddEventHandler(internalEvent, function(...)
        if self:isPointInside(PolyZone.getPlayerPosition(), zoneName) then TriggerEvent(eventName, ...) end
    end)
end

function PolyZone:removeEvent(eventName)
    local handler = self.events and self.events[eventName]
    if handler then RemoveEventHandler(handler) end
    if self.events then self.events[eventName] = nil end
end
return PolyZone
