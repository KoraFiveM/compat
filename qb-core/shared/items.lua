-- Forwarder: populates QBShared.Items in the including resource's VM from
-- kora_core (live legacy-shaped view). See README.
QBShared = QBShared or {}
local F = assert(load(assert(LoadResourceFile('qb-core', 'shared/_forward.lua'), '[qb-core-wrapper] missing shared/_forward.lua'), '@qb-core/shared/_forward.lua'))()
QBShared.Items = F.shared('Items')
