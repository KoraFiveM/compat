# Contributing to compat

Compatibility resources. Vendored upstream code (`ox_lib/`, `PolyZone/`) is kept close to upstream and is allowlisted in `test/print_allowlist.txt`.

Diagnostics use Kora.logging, not print. The guard `lua test/no_raw_print.lua` must pass before you open a PR.
