-- Forwarder: loads kora_core's shared/locale.lua into the consumer's VM.
-- A plain shared_script of kora_core's file would run in this wrapper's VM instead.
local chunk = LoadResourceFile('kora_core', 'shared/locale.lua')
assert(chunk, '[qb-core-wrapper] could not read kora_core/shared/locale.lua -- is kora_core present?')
local fn = assert(load(chunk, '@kora_core/shared/locale.lua'))
fn()
