-- ox_lib owns the public API and caller identity; kora_lib owns the one shared
-- browser surface. The final owner argument is private bridge metadata and is
-- never visible to a consumer using lib.* or exports.ox_lib:*.
local qblib = exports.kora_lib
local settings = require 'resource.settings'
local progress

local function owner()
    return GetInvokingResource() or cache.resource
end

function lib.alertDialog(data, timeout)
    return qblib:ox_alertDialog(data, timeout, owner())
end

function lib.closeAlertDialog(reason)
    return qblib:ox_closeAlertDialog(reason, owner())
end

function lib.setClipboard(value)
    return qblib:ox_setClipboard(value, owner())
end

function lib.showContext(id)
    return qblib:ox_showContext(id, owner())
end

function lib.registerContext(context)
    return qblib:ox_registerContext(context, owner())
end

function lib.getOpenContextMenu()
    return qblib:ox_getOpenContextMenu(owner())
end

function lib.hideContext(onExit)
    return qblib:ox_hideContext(onExit, owner())
end

function lib.inputDialog(heading, rows, options)
    return qblib:ox_inputDialog(heading, rows, options, owner())
end

function lib.closeInputDialog()
    return qblib:ox_closeInputDialog(owner())
end

function lib.setNuiFocus(allowInput, disableCursor)
    return qblib:ox_setNuiFocus(allowInput, disableCursor, owner())
end

function lib.resetNuiFocus()
    return qblib:ox_resetNuiFocus(owner())
end

function lib.registerMenu(data, callback)
    return qblib:ox_registerMenu(data, callback, owner())
end

function lib.showMenu(id, startIndex)
    return qblib:ox_showMenu(id, startIndex, owner())
end

function lib.hideMenu(onExit)
    return qblib:ox_hideMenu(onExit, owner())
end

function lib.setMenuOptions(id, options, index)
    return qblib:ox_setMenuOptions(id, options, index, owner())
end

function lib.getOpenMenu()
    return qblib:ox_getOpenMenu(owner())
end

function lib.notify(data)
    local sound = settings.notification_audio and data.sound
    local payload = table.clone(data)
    payload.sound = nil
    payload.position = payload.position or settings.notification_position

    local result = qblib:ox_notify(payload, owner())

    if sound then
        if sound.bank then lib.requestAudioBank(sound.bank) end

        local soundId = GetSoundId()
        PlaySoundFrontend(soundId, sound.name, sound.set, true)
        ReleaseSoundId(soundId)

        if sound.bank then ReleaseNamedScriptAudioBank(sound.bank) end
    end

    return result
end

function lib.defaultNotify(data)
    data.type = data.status
    if data.type == 'inform' then data.type = 'info' end
    return lib.notify(data)
end

local function runProgress(data, method)
    while progress ~= nil do Wait(0) end
    if OxProgressProps.interrupted(data) then return nil end

    progress = data
    local resourceName = owner()
    local ok, result, extra = OxProgressProps.run(data, resourceName, function()
        if progress == false then return false end
        return qblib[method](qblib, data, resourceName)
    end)
    progress = nil

    if not ok then error(result, 2) end
    if extra then error(extra, 2) end

    return result
end

function lib.progressBar(data)
    return runProgress(data, 'ox_progressBar')
end

function lib.progressCircle(data)
    return runProgress(data, 'ox_progressCircle')
end

function lib.cancelProgress()
    if not progress then error('No progress bar is active', 2) end
    progress = false

    if qblib:ox_progressActive(owner()) then
        qblib:ox_cancelProgress(owner())
    end
end

function lib.progressActive()
    return progress and true
end

RegisterCommand('cancelprogress', function()
    if progress and progress.canCancel then lib.cancelProgress() end
end)

RegisterKeyMapping('cancelprogress', locale('cancel_progress'), 'keyboard', 'x')

function lib.registerRadial(radial)
    return qblib:ox_registerRadial(radial, owner())
end

function lib.getCurrentRadialId()
    return qblib:ox_getCurrentRadialId(owner())
end

function lib.hideRadial()
    return qblib:ox_hideRadial(owner())
end

function lib.addRadialItem(items, parentMenuId)
    return qblib:ox_addRadialItem(items, parentMenuId, owner())
end

function lib.removeRadialItem(id, parentMenuId)
    return qblib:ox_removeRadialItem(id, parentMenuId, owner())
end

function lib.clearRadialItems()
    return qblib:ox_clearRadialItems(owner())
end

function lib.disableRadial(state)
    return qblib:ox_disableRadial(state, owner())
end

function lib.showRadialMenu(id)
    return qblib:ox_showRadialMenu(id, owner())
end

function lib.skillCheck(difficulty, inputs)
    return qblib:ox_skillCheck(difficulty, inputs, owner())
end

function lib.cancelSkillCheck()
    return qblib:ox_cancelSkillCheck(owner())
end

function lib.skillCheckActive()
    return qblib:ox_skillCheckActive(owner())
end

function lib.showTextUI(text, options)
    return qblib:ox_showTextUI(text, options, owner())
end

function lib.hideTextUI()
    return qblib:ox_hideTextUI(owner())
end

function lib.isTextUIOpen()
    return qblib:ox_isTextUIOpen(owner())
end

RegisterNetEvent('ox_lib:alertDialog', function(data)
    lib.alertDialog(data)
end)

RegisterNetEvent('ox_lib:notify', function(data)
    lib.notify(data)
end)

RegisterNetEvent('ox_lib:defaultNotify', function(data)
    lib.defaultNotify(data)
end)
