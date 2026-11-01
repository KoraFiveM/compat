-- Forwarder. A consumer's `shared_script '@qb-core/shared/locale.lua'` lands
-- here; we immediately hand off to kora_core's real implementation, which builds
-- the `Locale` global (and the `Lang` instance its own locales/*.lua files
-- expect) in that consumer's VM. Keeping this a pure forward means there is one
-- implementation to maintain (kora_core/shared/locale.lua), not two.
--
-- We cannot `shared_script '@kora_core/shared/locale.lua'` from HERE -- that would
-- run it in this wrapper's VM, not the consumer's. Instead the consumer that
-- included us gets kora_core's file loaded into ITS VM via the load below.
-- Identical technique to kora_sql/stubs/oxmysql/lib/MySQL.lua.
local chunk = LoadResourceFile('kora_core', 'shared/locale.lua')
assert(chunk, '[qb-core-wrapper] could not read kora_core/shared/locale.lua -- is kora_core present?')
local fn = assert(load(chunk, '@kora_core/shared/locale.lua'))
fn()
