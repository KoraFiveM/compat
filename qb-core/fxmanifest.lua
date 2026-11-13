fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qb-core'
author 'Jamie'
version '1.0.0'
description 'Drop-in wrapper: resolves @qb-core/... file includes to qbcore'

-- This wrapper exists ONLY to satisfy third-party manifests that contain
--   shared_script '@qb-core/shared/locale.lua'
-- (real qb-doorlock, qb-banking and qb-recyclejob all do).
--
-- FiveM resolves an '@name/path' include against a REAL resource whose
-- registered name is literally `name`. That resolution is a SEPARATE
-- mechanism from exports and dependencies: `provide 'qb-core'` in
-- kora_core/fxmanifest.lua satisfies another resource's `dependency 'qb-core'`
-- and (with the __cfx_export_ identity hijack in kora_core/compat/*) makes
-- exports['qb-core']:Fn() resolve -- but it does NOT make an @-import
-- resolve. Nothing about the export identity reaches the file loader.
--
-- Before this wrapper existed, that include failed outright:
--   [c-scripting-core] Failed to load script @qb-core/shared/locale.lua.
-- which left `Locale` nil in every legacy consumer's VM and cascaded into
-- "attempt to index a nil value (global 'Locale')" in their locales/*.lua.
--
-- Same shape of shim as kora_sql/stubs/{oxmysql,mysql-async} -- a real resource
-- ship of the file, whose contents forward to the real implementation so
-- there is one copy to maintain. See [compat]/README.md.

dependency 'kora_core'

files {
    'config.lua',
    'shared/_forward.lua',
    'shared/locale.lua',
    'shared/main.lua',
    'shared/items.lua',
    'shared/jobs.lua',
    'shared/gangs.lua',
    'shared/vehicles.lua',
    'shared/weapons.lua',
    'shared/locations.lua'
}
