#!/usr/bin/env bash
# Runs every PolyZone smoke test with plain Lua (no busted). Exits non-zero on
# any failure.
set -uo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lua_bin="${LUA:-lua}"
status=0
for file in "$dir"/smoke/*.lua; do
    echo "== $(basename "$file" .lua) =="
    if ! ( cd "$dir/.." && "$lua_bin" "$file" ); then status=1; fi
    echo
done
exit "$status"
