-- ComboZone.lua
--
-- Combines already-created BoxZone/CircleZone/PolyZone objects into one
-- logical zone. Each child already manages its own live kora_lib zone (via
-- BoxZone:Create/CircleZone:Create/PolyZone:Create), so this delegates to
-- the children's own :onPlayerInOut/:isPointInside/:destroy rather than
-- rebuilding kora_lib zones itself -- the previous implementation reconstructed
-- a SECOND kora_lib zone per child (double the tick-loop candidates for zero
-- benefit), only tore down its own copies on :onPlayerInOut (leaking the
-- children's originals forever), and had no wrapper branch for poly children
-- at all (fell through to a raw-data path that read fields PolyZone:Create
-- never sets).
ComboZone = {}

local MAP_MIN_X, MAP_MIN_Y, MAP_MAX_X, MAP_MAX_Y = -3700, -4400, 4500, 8000
local GRID_COLUMNS, GRID_ROWS = 34, 50
local GRID_WIDTH = (MAP_MAX_X - MAP_MIN_X) / GRID_COLUMNS
local GRID_HEIGHT = (MAP_MAX_Y - MAP_MIN_Y) / GRID_ROWS

setmetatable(ComboZone, {
    __index = PolyZone
})

local function watchZone(self, zone, callback)
    zone:onPlayerInOut(function(isInside)
        if self.destroyed or self.paused or self._onPlayerInOut ~= callback or not self._members[zone] then return end
        self._insideByZone[zone] = isInside or nil
        local combined = next(self._insideByZone) ~= nil
        if combined ~= self._isInside then
            self._isInside = combined
            callback(combined, GetEntityCoords(PlayerPedId()), zone)
        end
    end)
end

local function difference(from, against)
    local result

    for i = 1, #from do
        local found = false
        for j = 1, #against do
            if from[i] == against[j] then
                found = true
                break
            end
        end
        if not found then
            result = result or {}
            result[#result + 1] = from[i]
        end
    end

    return result
end

local function copyZones(zones)
    local copy = {}
    for i = 1, #zones do copy[i] = zones[i] end
    return copy
end

local function gridBounds(zone)
    local center = zone.center or zone.coords
    local radius = zone.radius or zone.boundingRadius
    if center == nil or not Kora.util.isFiniteNumber(center.x) or not Kora.util.isFiniteNumber(center.y)
        or not Kora.util.isFiniteNumber(radius) or radius < 0 then
        return nil
    end

    local minX = math.floor((center.x - radius - MAP_MIN_X) / GRID_WIDTH)
    local maxX = math.floor((center.x + radius - MAP_MIN_X) / GRID_WIDTH)
    local minY = math.floor((center.y - radius - MAP_MIN_Y) / GRID_HEIGHT)
    local maxY = math.floor((center.y + radius - MAP_MIN_Y) / GRID_HEIGHT)
    if minX < 0 or maxX >= GRID_COLUMNS or minY < 0 or maxY >= GRID_ROWS then return nil end
    return minX, maxX, minY, maxY
end

local function addToGrid(combo, zone)
    local minX, maxX, minY, maxY = gridBounds(zone)
    if not minX then
        combo.unindexedZones[#combo.unindexedZones + 1] = zone
        return
    end

    for y = minY, maxY do
        local row = combo.grid[y]
        if not row then
            row = {}
            combo.grid[y] = row
        end
        for x = minX, maxX do
            local cell = row[x]
            if not cell then
                cell = {}
                row[x] = cell
            end
            cell[#cell + 1] = zone
        end
    end
end

local function rebuildGrid(combo)
    combo.grid, combo.unindexedZones = {}, {}
    if not combo.useGrid then return end
    for i = 1, #combo.zones do addToGrid(combo, combo.zones[i]) end
end

local function watchGrid(combo, zone)
    if not combo.useGrid then return end
    zone._comboGridListeners = zone._comboGridListeners or {}
    zone._comboGridListeners[combo] = function() rebuildGrid(combo) end
end

local function unwatchGrid(combo, zone)
    if zone._comboGridListeners then zone._comboGridListeners[combo] = nil end
end

local function candidateLists(combo, point)
    if not combo.useGrid then return combo.zones, nil end
    local x = math.floor((point.x - MAP_MIN_X) / GRID_WIDTH)
    local y = math.floor((point.y - MAP_MIN_Y) / GRID_HEIGHT)
    local row = combo.grid[y]
    return row and row[x] or nil, combo.unindexedZones
end

local function containsAny(combo, point, zoneName, exhaustive)
    local indexed, unindexed = candidateLists(combo, point)
    local matches = exhaustive and {} or nil

    for i = 1, #(indexed or {}) do
        local zone = indexed[i]
        if (zoneName == nil or zone.name == zoneName) and zone:isPointInside(point) then
            if not exhaustive then return true, zone end
            matches[#matches + 1] = zone
        end
    end
    for i = 1, #(unindexed or {}) do
        local zone = unindexed[i]
        if (zoneName == nil or zone.name == zoneName) and zone:isPointInside(point) then
            if not exhaustive then return true, zone end
            matches[#matches + 1] = zone
        end
    end

    if exhaustive then return #matches > 0, matches end
    return false, nil
end

function ComboZone:Create(zones, options)
    if zones == nil then zones = {} end
    assert(type(zones) == 'table', 'ComboZone zones must be an array.')
    if options == nil then options = {} end
    assert(type(options) == 'table', 'ComboZone options must be a table.')
    assert(options.debugPoly == nil or type(options.debugPoly) == 'boolean', 'ComboZone debugPoly must be a boolean.')
    assert(options.debugBlip == nil or type(options.debugBlip) == 'boolean', 'ComboZone debugBlip must be a boolean.')

    local members = {}
    local zoneCount = 0
    for index, zone in pairs(zones) do
        assert(Kora.util.isInteger(index) and index >= 1 and type(zone) == 'table'
            and type(zone.isPointInside) == 'function',
            'ComboZone zones must be a dense array of PolyZone-compatible objects.')
        members[zone] = true
        zoneCount = zoneCount + 1
    end
    assert(zoneCount == #zones, 'ComboZone zones must be a dense array of PolyZone-compatible objects.')

    local object = setmetatable({
        zones = zones,
        type = "combo",
        name = options.name,
        useGrid = options.useGrid ~= false,
        isComboZone = true,

        debugPoly = options.debugPoly or false,
        debugColor = options.debugColor or { 0, 255, 0 },
        data = options.data or {},

        _onPlayerInOut = nil,
        _insideByZone = {},
        _isInside = false,
        _members = members,
        grid = {},
        unindexedZones = {},
        destroyed = false,
        paused = false,
    }, {
        __index = ComboZone
    })

    rebuildGrid(object)
    for i = 1, #zones do watchGrid(object, zones[i]) end

    if options.debugBlip then object:addDebugBlip() end
    return object
end

function ComboZone:new(zones, options)
    return ComboZone:Create(zones, options)
end

function ComboZone:onPlayerInOut(callback, waitInMS)
    assert(type(callback) == 'function', 'callback must be a function')
    assert(waitInMS == nil or (Kora.util.isFiniteNumber(waitInMS) and waitInMS >= 0), 'waitInMS must be a non-negative number')

    self._comboPollId = (self._comboPollId or 0) + 1
    if waitInMS ~= nil then
        self._onPlayerInOut = nil
        return self:onPointInOut(PolyZone.getPlayerPosition, callback, waitInMS)
    end

    self._onPlayerInOut = callback
    self._insideByZone = {}
    self._isInside = false

    for i = 1, #self.zones do
        local zone = self.zones[i]
        -- Real PolyZone's ComboZone:onPlayerInOut calls back as
        -- (isInside, point, insideZone) -- point is the PLAYER's own
        -- position (mkafrin/PolyZone's onPointInOut polls
        -- PolyZone.getPlayerPosition() itself), not anything read off the
        -- entering/exiting child zone. Computed fresh here rather than
        -- forwarded from the child's own callback args because those args
        -- aren't even consistent across child types (BoxZone's onEnter/
        -- onExit pass (isInside, coords, self); CircleZone's pass only
        -- (isInside)) -- real qb-ambulancejob/qb-policejob only ever combo
        -- BoxZone children, but computing it independently matches real
        -- PolyZone exactly regardless of child type. Previously this passed
        -- the child zone object itself as the 2nd argument (the exact
        -- position real callers do `#(point - vector3(...))` on), which
        -- broke qb-policejob's impound/garage location picker outright.
        watchZone(self, zone, callback)
    end

    return self
end

function ComboZone:onPointInOut(getPointCb, callback, waitInMS)
    assert(type(getPointCb) == 'function' and type(callback) == 'function', 'callbacks must be functions')
    assert(waitInMS == nil or (Kora.util.isFiniteNumber(waitInMS) and waitInMS >= 0), 'waitInMS must be a non-negative number')

    self._comboPollId = (self._comboPollId or 0) + 1
    local pollId = self._comboPollId

    CreateThread(function()
        local isInside = false
        local insideZone

        while not self.destroyed and self._comboPollId == pollId do
            if not self.paused then
                local point = getPointCb()
                local newIsInside, newInsideZone = self:isPointInside(point)

                if newIsInside ~= isInside then
                    callback(newIsInside, point, newInsideZone or insideZone)
                    isInside = newIsInside
                    insideZone = newInsideZone
                end
            end

            Wait(waitInMS or 500)
        end
    end)

    return self
end

function ComboZone:getZones(point)
    if not self.useGrid then return self.zones end
    local indexed, unindexed = candidateLists(self, point)
    if not indexed then return #unindexed > 0 and copyZones(unindexed) or nil end
    if #unindexed == 0 then return indexed end

    local zones = copyZones(indexed)
    for i = 1, #unindexed do zones[#zones + 1] = unindexed[i] end
    return zones
end

function ComboZone:AddZone(zone)
    assert(type(zone) == 'table' and type(zone.isPointInside) == 'function', 'zone must be a PolyZone-compatible object')
    assert(not self.destroyed, 'cannot add a zone to a destroyed ComboZone')

    self.zones[#self.zones + 1] = zone
    self._members[zone] = true
    if self.useGrid then addToGrid(self, zone) end
    watchGrid(self, zone)

    if self._onPlayerInOut then
        watchZone(self, zone, self._onPlayerInOut)
    end
end

function ComboZone:RemoveZone(nameOrFn)
    local matches = type(nameOrFn) == 'function' and nameOrFn
        or type(nameOrFn) == 'string' and function(zone) return zone.name == nameOrFn end

    if not matches then return nil end

    for i = 1, #self.zones do
        local zone = self.zones[i]
        if matches(zone) then
            table.remove(self.zones, i)
            self._members[zone] = nil
            self._insideByZone[zone] = nil
            self._isInside = next(self._insideByZone) ~= nil
            unwatchGrid(self, zone)
            rebuildGrid(self)
            return zone
        end
    end
end

function ComboZone:isPointInside(point, zoneName)
    if self.destroyed then return false, nil end
    return containsAny(self, point, zoneName, false)
end

function ComboZone:isPointInsideExhaustive(point, insideZones)
    insideZones = insideZones or {}
    for i = #insideZones, 1, -1 do insideZones[i] = nil end

    if self.destroyed then return false, insideZones end

    local isInside, matches = containsAny(self, point, nil, true)
    for i = 1, #matches do insideZones[#insideZones + 1] = matches[i] end
    return isInside, insideZones
end

function ComboZone:onPointInOutExhaustive(getPointCb, callback, waitInMS)
    assert(type(getPointCb) == 'function' and type(callback) == 'function', 'callbacks must be functions')
    assert(waitInMS == nil or (Kora.util.isFiniteNumber(waitInMS) and waitInMS >= 0), 'waitInMS must be a non-negative number')

    CreateThread(function()
        local previous = {}
        local current = {}
        local wasInside

        while not self.destroyed do
            if not self.paused then
                local point = getPointCb()
                local isInside
                isInside, current = self:isPointInsideExhaustive(point, current)
                local entered = difference(current, previous)
                local left = difference(previous, current)

                if isInside ~= wasInside or entered or left then
                    local snapshot = copyZones(current)
                    callback(isInside, point, snapshot, entered, left)
                    previous = snapshot
                    wasInside = isInside
                end
            end

            Wait(waitInMS or 500)
        end
    end)

    return self
end

function ComboZone:onPlayerInOutExhaustive(callback, waitInMS)
    return self:onPointInOutExhaustive(PolyZone.getPlayerPosition, callback, waitInMS)
end

function ComboZone:draw(forceDraw)
    if self.destroyed then return end

    for i = 1, #self.zones do
        local zone = self.zones[i]
        if zone and not zone.destroyed and zone.draw then
            zone:draw(forceDraw)
        end
    end
end

function ComboZone:printInfo()
    local counts = { poly = 0, box = 0, circle = 0, entity = 0, combo = 0 }

    for i = 1, #self.zones do
        local zone = self.zones[i]
        if zone then
            if zone.isEntityZone then counts.entity = counts.entity + 1
            elseif zone.isCircleZone then counts.circle = counts.circle + 1
            elseif zone.isComboZone then counts.combo = counts.combo + 1
            elseif zone.isBoxZone then counts.box = counts.box + 1
            elseif zone.isPolyZone then counts.poly = counts.poly + 1 end
        end
    end

    local name = self.name and ('"' .. self.name .. '"') or nil
    print('-----------------------------------------------------')
    print('[PolyZone] Info for ComboZone { name = ' .. tostring(name) .. ' }:')
    print('[PolyZone]   Total zones: ' .. #self.zones)
    if counts.box > 0 then print('[PolyZone]   BoxZones: ' .. counts.box) end
    if counts.circle > 0 then print('[PolyZone]   CircleZones: ' .. counts.circle) end
    if counts.poly > 0 then print('[PolyZone]   PolyZones: ' .. counts.poly) end
    if counts.entity > 0 then print('[PolyZone]   EntityZones: ' .. counts.entity) end
    if counts.combo > 0 then print('[PolyZone]   ComboZones: ' .. counts.combo) end
    print('-----------------------------------------------------')
end

function ComboZone:addDebugBlip()
    local blips = {}

    for i = 1, #self.zones do
        local zone = self.zones[i]
        if zone.addDebugBlip then
            blips[#blips + 1] = zone:addDebugBlip()
        end
    end

    self.debugBlips = blips
    return blips
end

function ComboZone:removeDebugBlip()
    for i = 1, #self.zones do
        local zone = self.zones[i]
        if zone.removeDebugBlip then zone:removeDebugBlip() end
    end
    self.debugBlips = nil
end

function ComboZone:destroy()
    if self.destroyed then return end
    self.destroyed = true
    self._insideByZone = {}
    for i = 1, #self.zones do unwatchGrid(self, self.zones[i]) end
    for eventName in pairs(self.events or {}) do
        self:removeEvent(eventName)
    end
    self:removeDebugBlip()
    for i = 1, #self.zones do
        local zone = self.zones[i]
        if zone.destroy then zone:destroy() end
    end
end

function ComboZone:remove()
    self:destroy()
end

return ComboZone
