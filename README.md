# compat

Compatibility resources for Kora Framework. Deployed by the txAdmin recipe to `resources/[compat]`.

| Resource | Purpose |
| --- | --- |
| `PolyZone` | Zone library used by legacy scripts. |
| `qb-core` | Wrapper that resolves `@qb-core/...` file includes to Kora's QBCore compatibility layer. Needs `kora_core`. |
| `mysql-async` | Placeholder that forwards `@mysql-async/lib/MySQL.lua` and `dependency 'mysql-async'` to `kora_sql`. Never run real mysql-async alongside it. |
| `oxmysql` | Placeholder that forwards `@oxmysql/lib/MySQL.lua` and `dependency 'oxmysql'` to `kora_sql`. Never run real oxmysql alongside it. |

Start order: `oxmysql` and `mysql-async` after `kora_sql`, `qb-core` after `kora_core`, then the rest of `[compat]`.
