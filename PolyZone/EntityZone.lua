-- Moving model-bounds zone compatible with PolyZone's EntityZone API. It
-- cannot use a static Kora.zones.box: recreating one whenever a vehicle turns
-- would churn the shared spatial grid. Model-local containment stays correct
-- as the entity moves and costs only the native coordinate transform.
EntityZone = {}

setmetatable(EntityZone, { __index = BoxZone })

local function expandBounds(values, default, label)
    values = values or { default, default, default }
    assert(type(values) == 'table', ('EntityZone %s must be an array.'):format(label))
    local count = 0
    for index, value in pairs(values) do
        assert(Kora.util.isInteger(index) and index >= 1 and Kora.util.isFiniteNumber(value),
            ('EntityZone %s must be a dense array of finite numbers.'):format(label))
        count = count + 1
    end
    assert((count == 3 or count == 6) and count == #values,
        ('EntityZone %s must contain 3 or 6 finite values.'):format(label))
    if count == 3 then
        return { values[1], values[1], values[2], values[2], values[3], values[3] }
    end
    return values
end

local function zBounds(entity, dimensions, scale, offset)
    local minimum, maximum = dimensions[1], dimensions[2]
    local minZ, maxZ = math.huge, -math.huge

    for xIndex = 0, 1 do
        local x = xIndex == 0 and minimum.x or maximum.x
        for yIndex = 0, 1 do
            local y = yIndex == 0 and minimum.y or maximum.y
            for zIndex = 0, 1 do
                local z = zIndex == 0 and minimum.z or maximum.z
                local point = GetOffsetFromEntityInWorldCoords(entity, x, y, z)
                minZ = math.min(minZ, point.z)
                maxZ = math.max(maxZ, point.z)
            end
        end
    end

    local center = (minZ + maxZ) / 2
    minZ = center - (center - minZ) * scale[6] - offset[6]
    maxZ = center + (maxZ - center) * scale[5] + offset[5]
    assert(maxZ > minZ, 'EntityZone scale and offset must leave a positive vertical extent.')
    return minZ, maxZ
end

local function ensurePlayerPoll(self)
    if self.playerPollStarted then return end
    self.playerPollStarted = true

    CreateThread(function()
        local wasInside = false
        while not self.destroyed do
            if not DoesEntityExist(self.entity) then
                if wasInside and not self.paused and self._onPlayerInOut then
                    self._onPlayerInOut(false, PolyZone.getPlayerPosition(), self)
                end
                return
            end
            if not self.paused then
                local point = PolyZone.getPlayerPosition()
                local isInside = self:isPointInside(point)
                if isInside ~= wasInside and self._onPlayerInOut then
                    self._onPlayerInOut(isInside, point, self)
                end
                wasInside = isInside
            end
            Wait(self.waitInMS)
        end
    end)
end

function EntityZone:Create(entity, options)
    assert(Kora.util.isInteger(entity) and entity > 0, 'EntityZone entity must be a positive finite handle.')
    assert(DoesEntityExist(entity), 'Entity does not exist')
    if options == nil then options = {} end
    assert(type(options) == 'table', 'EntityZone options must be a table.')
    assert(options.useZ == nil or type(options.useZ) == 'boolean', 'EntityZone useZ must be a boolean.')
    assert(options.debugPoly == nil or type(options.debugPoly) == 'boolean', 'EntityZone debugPoly must be a boolean.')
    assert(options.debugBlip == nil or type(options.debugBlip) == 'boolean', 'EntityZone debugBlip must be a boolean.')
    assert(options.waitInMS == nil or (Kora.util.isFiniteNumber(options.waitInMS) and options.waitInMS >= 0),
        'waitInMS must be a non-negative number.')

    local minimum, maximum = GetModelDimensions(GetEntityModel(entity))
    local dimensions = { minimum, maximum }
    local scale = expandBounds(options.scale, 1.0, 'scale')
    local offset = expandBounds(options.offset, 0.0, 'offset')
    local halfX = (maximum.x - minimum.x) / 2
    local halfY = (maximum.y - minimum.y) / 2
    local minX = -halfX * scale[3] - offset[3]
    local maxX = halfX * scale[4] + offset[4]
    local minY = -halfY * scale[2] - offset[2]
    local maxY = halfY * scale[1] + offset[1]
    assert(maxX > minX and maxY > minY,
        'EntityZone scale and offset must leave positive horizontal extents.')
    if options.useZ then zBounds(entity, dimensions, scale, offset) end

    local object = setmetatable({
        type = 'entity',
        entity = entity,
        dimensions = dimensions,
        scale = scale,
        offset = offset,
        minX = minX,
        maxX = maxX,
        minY = minY,
        maxY = maxY,
        useZ = options.useZ == true,
        name = options.name,
        data = options.data or {},
        debugPoly = options.debugPoly or false,
        debugColor = options.debugColor or { 0, 255, 0 },
        destroyed = false,
        paused = false,
        isEntityZone = true,
        waitInMS = options.waitInMS or 500,
        damageEventHandlers = {},
    }, { __index = EntityZone })

    if options.debugBlip then object:addDebugBlip() end
    return object
end

function EntityZone:new(entity, options)
    return EntityZone:Create(entity, options)
end

function EntityZone:isPointInside(point)
    if self.destroyed or not DoesEntityExist(self.entity) then return false end
    assert(type(point) == 'table' and Kora.util.isFiniteNumber(point.x) and Kora.util.isFiniteNumber(point.y) and Kora.util.isFiniteNumber(point.z),
        'EntityZone point must have x, y, and z coordinates.')

    local localPoint = GetOffsetFromEntityGivenWorldCoords(self.entity, point.x, point.y, point.z)
    if localPoint.x < self.minX or localPoint.x > self.maxX or localPoint.y < self.minY or localPoint.y > self.maxY then
        return false
    end
    if not self.useZ then return true end

    local minZ, maxZ = zBounds(self.entity, self.dimensions, self.scale, self.offset)
    return point.z >= minZ and point.z <= maxZ
end

function EntityZone:onPlayerInOut(callback, waitInMS)
    assert(type(callback) == 'function', 'callback must be a function')
    assert(waitInMS == nil or (Kora.util.isFiniteNumber(waitInMS) and waitInMS >= 0), 'waitInMS must be a non-negative number.')
    if waitInMS ~= nil then self.waitInMS = waitInMS end
    self._onPlayerInOut = callback
    ensurePlayerPoll(self)
    return self
end

function EntityZone:TransformPoint(point)
    return point
end

function EntityZone:draw(forceDraw)
    if self.destroyed or (not forceDraw and not self.debugPoly) or not DoesEntityExist(self.entity) then return end

    local coords = GetEntityCoords(self.entity)
    local function point(x, y)
        local world = GetOffsetFromEntityInWorldCoords(self.entity, x, y, 0.0)
        return vector3(world.x, world.y, coords.z)
    end

    self.points = {
        point(self.minX, self.minY), point(self.maxX, self.minY),
        point(self.maxX, self.maxY), point(self.minX, self.maxY),
    }
    if self.useZ then
        self.minZ, self.maxZ = zBounds(self.entity, self.dimensions, self.scale, self.offset)
    else
        self.minZ, self.maxZ = nil, nil
    end

    return PolyZone.draw(self, true)
end

function EntityZone:onEntityDamaged(callback)
    assert(type(callback) == 'function', 'callback must be a function')
    assert(not self.destroyed, 'cannot add a damage callback to a destroyed EntityZone')
    local entity = self.entity
    local handler = AddEventHandler('gameEventTriggered', function(name, args)
        if self.destroyed or self.paused or name ~= 'CEventNetworkEntityDamage' or type(args) ~= 'table' or args[1] ~= entity then return end
        local ok, err = pcall(callback, args[4] == 1, args[2], args[5], args[10] == 1)
        if not ok then print(('^3[PolyZone]^7 entity damage callback errored: %s'):format(tostring(err))) end
    end)
    self.damageEventHandlers[#self.damageEventHandlers + 1] = handler
    return handler
end

function EntityZone:addDebugBlip()
    assert(DoesEntityExist(self.entity), 'Entity does not exist')
    self.coords = GetEntityCoords(self.entity)
    local blip = PolyZone.addDebugBlip(self)

    CreateThread(function()
        while not self.destroyed and self.debugBlip == blip do
            if not DoesEntityExist(self.entity) then
                self:removeDebugBlip()
                return
            end
            local coords = GetEntityCoords(self.entity)
            SetBlipCoords(blip, coords.x, coords.y, 0.0)
            Wait(0)
        end
    end)

    return blip
end

function EntityZone:destroy()
    if self.destroyed then return end
    self.destroyed = true
    for i = 1, #self.damageEventHandlers do RemoveEventHandler(self.damageEventHandlers[i]) end
    self.damageEventHandlers = {}
    for eventName in pairs(self.events or {}) do
        self:removeEvent(eventName)
    end
    self:removeDebugBlip()
end

function EntityZone:remove()
    self:destroy()
end

function EntityZone:setPaused(paused)
    self.paused = paused == true
end

function EntityZone:isPaused()
    return self.paused
end

return EntityZone
