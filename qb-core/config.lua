-- Forwarder: populates QBConfig in the including resource's VM from kora_core's
-- QBCore.Config. Falls back to a minimal stock-shaped table if unavailable.
local F = assert(load(assert(LoadResourceFile('qb-core', 'shared/_forward.lua'), '[qb-core-wrapper] missing shared/_forward.lua'), '@qb-core/shared/_forward.lua'))()
QBConfig = F.config() or {
    MaxPlayers = GetConvarInt('sv_maxclients', 48),
    UpdateInterval = 5,
    StatusInterval = 5000,
    Money = { MoneyTypes = { cash = 500, bank = 5000, crypto = 0 }, DontAllowMinus = { 'cash', 'crypto' }, MinusLimit = -5000, PayCheckTimeOut = 10, PayCheckSociety = false },
    Player = { HungerRate = 4.2, ThirstRate = 3.8, Bloodtypes = { 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-' }, MaxWeight = 120000, MaxInvSlots = 41 },
    Server = {},
    Notify = {},
}
