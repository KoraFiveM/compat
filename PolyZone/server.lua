local eventPrefix = '__PolyZone__:'

function triggerZoneEvent(eventName, ...)
  assert(type(eventName) == 'string' and eventName ~= '', 'eventName must be a non-empty string')
  TriggerClientEvent(eventPrefix .. eventName, -1, ...)
end

RegisterNetEvent("PolyZone:TriggerZoneEvent")
AddEventHandler("PolyZone:TriggerZoneEvent", function(eventName, ...)
  if source ~= nil and source ~= 0 then return end
  triggerZoneEvent(eventName, ...)
end)

exports("TriggerZoneEvent", triggerZoneEvent)
