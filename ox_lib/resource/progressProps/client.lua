--[[
    Adapted from https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

local createdProps = {}
local maxProps = GetConvarInt('ox:progressPropLimit', 2)
local playerState = LocalPlayer.state

OxProgressProps = {}

local function loadPropModel(model)
    local ok, result = pcall(lib.requestModel, model)

    if not ok then return false, result end

    SetModelAsNoLongerNeeded(result)

    if IsModelAPed(result) or IsModelAVehicle(result) then
        return false, ("model '%s' is not a valid object"):format(model)
    end

    local min, max = GetModelDimensions(result)
    local size = max - min

    if math.max(size.x, size.y, size.z) > 2.5 then
        return false, ("model '%s' is too large"):format(model)
    end

    return true, result
end

local function createProp(ped, prop)
    local ok, result = loadPropModel(prop.model)

    if not ok or not result then return lib.print.error(result or '') end

    local coords = GetEntityCoords(ped)
    local object = CreateObject(result, coords.x, coords.y, coords.z, false, false, false)

    AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, prop.bone or 60309), prop.pos.x, prop.pos.y, prop.pos.z,
        prop.rot.x, prop.rot.y, prop.rot.z, true, true, false, true, prop.rotOrder or 0, true)
    SetModelAsNoLongerNeeded(result)

    return object
end

local function deleteProgressProps(serverId)
    local playerProps = createdProps[serverId]

    if not playerProps then return end

    createdProps[serverId] = nil

    for index = 1, #playerProps do
        local prop = playerProps[index]

        if DoesEntityExist(prop) then DeleteEntity(prop) end
    end
end

local invalidPropData = "lib.requestModel received invalid prop data from resource '%s' (%s)"

---@param data table
---@param resourceName string
---@return boolean published
function OxProgressProps.prepare(data, resourceName)
    if data.prop == nil then return false end

    local propType = table.type(data.prop)

    if propType == 'empty' then
        lib.print.warn(invalidPropData:format(resourceName, 'table is empty'))
    elseif propType == 'array' then
        for index = #data.prop, 1, -1 do
            local model = data.prop[index].model

            if model then
                local ok, err = loadPropModel(model)

                if not ok then
                    lib.print.warn(invalidPropData:format(resourceName, err))
                    table.remove(data.prop, index)
                end
            else
                lib.print.warn(invalidPropData:format(resourceName, 'model is undefined'))
                table.remove(data.prop, index)
            end
        end
    else
        local model = data.prop.model

        if model then
            local ok, err = loadPropModel(model)

            if not ok then
                lib.print.warn(invalidPropData:format(resourceName, err))
                data.prop = nil
            end
        else
            lib.print.warn(invalidPropData:format(resourceName, 'model is undefined'))
            data.prop = nil
        end
    end

    TriggerServerEvent('ox_lib:progressProps', data.prop)
    return data.prop ~= nil
end

function OxProgressProps.clear()
    TriggerServerEvent('ox_lib:progressProps', nil)
end

---@param data table
---@return boolean
function OxProgressProps.interrupted(data)
    if not data.useWhileDead and IsEntityDead(cache.ped) then return true end
    if not data.allowRagdoll and IsPedRagdoll(cache.ped) then return true end
    if not data.allowCuffed and IsPedCuffed(cache.ped) then return true end
    if not data.allowFalling and IsPedFalling(cache.ped) then return true end
    if not data.allowSwimming and IsPedSwimming(cache.ped) then return true end
    return false
end

---@param data table
---@param resourceName string
---@param callback function
---@return boolean ok
---@return any result
---@return any extra
function OxProgressProps.run(data, resourceName, callback)
    local previousBusy = playerState.invBusy
    playerState.invBusy = true

    local published = false
    local ok, result, extra = pcall(function()
        published = OxProgressProps.prepare(data, resourceName)
        return callback()
    end)

    if published then OxProgressProps.clear() end
    playerState.invBusy = previousBusy

    return ok, result, extra
end

RegisterNetEvent('onPlayerDropped', function(serverId)
    deleteProgressProps(serverId)
end)

AddStateBagChangeHandler('lib:progressProps', nil, function(bagName, _, value, _, replicated)
    if replicated then return end

    local player = GetPlayerFromStateBagName(bagName)
    if player == 0 or player == PlayerId() then return end

    local ped = GetPlayerPed(player)
    local serverId = GetPlayerServerId(player)

    if not value or createdProps[serverId] then
        return deleteProgressProps(serverId)
    end

    local playerProps = {}

    if value.model then
        local prop = createProp(ped, value)

        if prop then playerProps[#playerProps + 1] = prop end
    else
        local propCount = math.min(maxProps, #value)

        for index = 1, propCount do
            local prop = createProp(ped, value[index])

            if prop then playerProps[#playerProps + 1] = prop end
        end
    end

    createdProps[serverId] = playerProps
end)
