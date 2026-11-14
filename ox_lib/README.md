# ox_lib compatibility resource

This resource preserves the FiveM-facing ox_lib 3.39.0 import and API surface
while kora_lib owns the shared UI implementation. Existing resources can keep:

```lua
shared_script '@ox_lib/init.lua'
```

and continue to use the global `lib` and `cache` APIs or `exports.ox_lib`.

The consumer-local loader, lazy imports, data structures, callbacks, points,
zones, streaming helpers and other non-UI modules are pinned verbatim to
Overextended commit `b8f5a04351b1d427e0e112150d36094e9889ec7b` under the
LGPL-3.0-or-later license. The resource-owned UI exports are a thin bridge to
kora_lib, avoiding a second NUI page and duplicate focus state.

The pinned player locale and notification preferences remain owned here.
Locale dictionaries reload in each consumer exactly as they do upstream, and
the decoded ox browser labels are bootstrapped into kora_lib and updated on every
`lib.setLocale` call.

Client state-bag write requests validate their bag, target ID, key, and
replication mode before reaching hook dispatch or FiveM state natives. Invalid
requests return `false`; they do not throw or mutate state.

kora_lib deliberately translates presentation onto its own design system. Any
presentation-only differences are documented by kora_lib rather than described
as byte-for-byte upstream UI parity; the manifest/import surface, public
exports, return values, ownership, and non-UI modules are the compatibility
contract of this resource.

## Install only for a legacy manifest import

This wrapper is optional. Do not add it to a default configuration: start it
only when an installed legacy resource imports `@ox_lib/init.lua`. Start
`kora_lib` before this resource, and start an importing resource after `ox_lib`:

```cfg
ensure kora_lib
ensure ox_lib # only for @ox_lib/... imports
ensure ox_inventory # stock ox_inventory, if used, goes after ox_lib
```

Order: `kora_lib` -> `ox_lib` -> `ox_inventory` (and any other `@ox_lib` consumer).
`lib.hasLoaded()` returns `true` once `kora_lib` is `started`; otherwise it
returns the string `^1qblib must be started before ox_lib compatibility
consumers.^0`, which consumers such as ox_inventory print and abort on.

## Modifications to upstream behaviour (2026-10-31)

Shim-owned files only; the 106 pinned upstream files are untouched.

- `resource/version/server.lua`: no outbound HTTP. The start-up
  `lib.versionCheck('overextended/ox_lib')` call and its update notice are
  removed. `lib.versionCheck` stays available but is a no-op unless the convar
  `ox:versionCheck` is `true` (default off), regardless of consumer gates such
  as `inventory:versioncheck`. At most one debug line (`ox:printlevel debug`).
- `resource/version/shared.lua`: `lib.checkDependency` treats `qbx_core` and
  `qbx_vehicles` as satisfied when `kora_core` is `started` (alias table; no
  fake resources). Otherwise upstream results and messages are unchanged.
  `oxmysql` is not aliased. Set `ox:dependencyAlias 0` to disable.

## Verify the wrapper

From this resource directory, run `bash test/run.sh`. It verifies the public
compatibility surface without starting `ox_lib` or adding it to a server
configuration.

## Continuous integration

`.github/workflows/parity.yml` runs `bash test/run.sh` on every push and pull
request with Lua 5.4 (`contents: read`, no secrets, `actions/checkout` pinned by
commit SHA). Only the Lua install touches the network; the checks are offline.
`test/run.sh` runs the vendored-file pin check, `test/compat.lua`, and
`test/parity.lua`, which extracts this resource's public surface (resource
exports by realm, `imports/` modules, locales, manifest keys, `ox_lib:*` events,
`ox:*` convars) and diffs it with `test/parity.golden.json` (ox_lib 3.39.0).
Anything missing fails, except the documented headless soft list in
`test/parity.lua` (`ui_page`, `games`, `rdr3_warning`, `ox:primaryColor`,
`ox:primaryShade`); extras are printed as `info:`. NUI actions/callbacks are not
part of the extracted surface. Regenerate the golden only on a reviewed version
bump: `lua5.4 test/parity.lua emit <ox_lib checkout> > test/parity.golden.json`.
