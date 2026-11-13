# qb-core (compat wrapper)

A wrapper resource whose only job is to **occupy the resource name `qb-core`**
so that legacy scripts' `@qb-core/...` file includes resolve.

It contains no framework logic. The real implementation is `kora_core`; this
resource forwards to it.

## The problem it solves

Real qb-core-era scripts (qb-doorlock, qb-banking, …) declare:

```lua
shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
}
```

FiveM has three separate mechanisms that all look like "resource identity", and
they do **not** cover each other:

| Mechanism | What satisfies it |
|---|---|
| `dependency 'qb-core'` | a real resource named `qb-core`, **or** any started resource with `provide 'qb-core'` |
| `exports['qb-core']:Fn()` | whichever resource registers the `__cfx_export_qb-core_Fn` event (the identity hijack kora_core's `compat/*` uses) |
| `shared_script '@qb-core/bar.lua'` | **only** a real, started resource literally named `qb-core`, with `bar.lua` in its `files {}` block |

`kora_core` already carries `provide 'qb-core'` and the export identity hijack, so
the first two rows are covered. The third is not: an `@name/path` include is
resolved by the *file loader*, which never consults `provide` or the export
registry.

Because a failed include is not a fatal error, the consumer starts anyway with
a missing global, and it surfaces later as a confusing error deep inside that
consumer's own code:

```
[c-scripting-core] Failed to load script @qb-core/shared/locale.lua.
[   script:qb-banking] SCRIPT ERROR: @qb-banking/locales/en.lua:33: attempt to index a nil value (global 'Locale')
```

## How it works

`shared/locale.lua` forwards to the canonical implementation rather than
duplicating it:

```lua
local chunk = LoadResourceFile('kora_core', 'shared/locale.lua')
local fn = assert(load(chunk, '@kora_core/shared/locale.lua'))
fn()
```

The forward — rather than a `shared_script '@kora_core/...'` in this resource's own
manifest — is the load-bearing detail: the consumer's include runs this file **in
the consumer's VM**, so the `Locale` global it defines lands where the consumer
can see it. A `shared_script` in this manifest would instead run it in *this*
resource's VM, where nothing needs it.

## Forwarded files

| Include | Defines (in the consumer's VM) |
|---|---|
| `@qb-core/shared/locale.lua` | `Locale` / `Lang` (kora_core's implementation) |
| `@qb-core/shared/main.lua` | `QBShared` helpers (`RandomStr`, `RandomInt`, `SplitStr`, `Trim`, `FirstToUpper`, `Round`, `IsFunction`, `ChangeVehicleExtra`, `SetDefaultVehicleExtras`) plus `StarterItems`, `MaleNoGloves`, `FemaleNoGloves` |
| `@qb-core/shared/items.lua` | `QBShared.Items` |
| `@qb-core/shared/jobs.lua` | `QBShared.Jobs` (stock zero-based string grades) |
| `@qb-core/shared/gangs.lua` | `QBShared.Gangs` |
| `@qb-core/shared/vehicles.lua` | `QBShared.Vehicles`, `QBShared.VehicleHashes` |
| `@qb-core/shared/weapons.lua` | `QBShared.Weapons` |
| `@qb-core/shared/locations.lua` | `QBShared.Locations` |
| `@qb-core/config.lua` | `QBConfig` (kora_core's `QBCore.Config`) |

Data is pulled at load time from kora_core's `exports['qb-core']:GetShared` /
`GetCoreObject`. It is a **snapshot** taken when the consumer loads; scripts
that need live changes should call the export again. If kora_core is not
started yet the tables are empty and a warning is printed. Other files from the
real qb-core (`client/`, `server/`) are not forwarded; use
`exports['qb-core']:GetCoreObject()` for those.

## Single source of truth

This resource is the only `qb-core` resource that should exist. A separate,
older copy cloned from `qbcore2/qb-core` may be present on servers (typically in
a `[compat]` folder next to a copy in `[test]`); it collides on the resource
name and **must be removed**.

## Tests

```sh
bash test/run.sh
```

Plain Lua with mocks; no server needed.

## Install

Place in `resources/[compat]/` and ensure it **after** `kora_core` (its
`LoadResourceFile` target must already exist) and **before** any legacy consumer:

```cfg
ensure kora_core
ensure qb-core
ensure qb-banking
```

The order is required: `qb-core` must be `ensure`d after `kora_core` and before
any qb script that includes `@qb-core/...`.

Do not run a real qb-core alongside this.
