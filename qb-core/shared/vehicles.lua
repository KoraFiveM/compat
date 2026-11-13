-- Forwarder: populates QBShared.Vehicles (and VehicleHashes, which stock
-- builds in the same file) in the including resource's VM from kora_core.
QBShared = QBShared or {}
local F = assert(load(assert(LoadResourceFile('qb-core', 'shared/_forward.lua'), '[qb-core-wrapper] missing shared/_forward.lua'), '@qb-core/shared/_forward.lua'))()
QBShared.Vehicles = F.shared('Vehicles')
QBShared.VehicleHashes = F.shared('VehicleHashes')
