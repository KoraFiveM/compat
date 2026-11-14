AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == cache.resource then return end

    exports.kora_lib:ox_disposeOwner(resourceName)
end)
