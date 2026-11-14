Copyright © 2021-2026 [Linden](https://github.com/thelindat), [Luke](https://github.com/LukeWasTakenn), and contributors  

The original source code is available at: [https://github.com/overextended/ox_lib](https://github.com/overextended/ox_lib)

## Modifications (LGPL-3.0 §2)

Changes made on 2026-10-31 by the Kora team to files derived from upstream
`resource/version/server.lua` and `resource/version/shared.lua` (ox_lib 3.39.0):
the start-up `lib.versionCheck` call was removed and `lib.versionCheck` made a
no-op unless `ox:versionCheck` is true; `lib.checkDependency` gained an alias
(`qbx_core`, `qbx_vehicles` -> `kora_core`). See README.md.

---

This project is licensed under the [LGPL‑3.0](https://www.gnu.org/licenses/lgpl-3.0.en.html) or later. A complete copy of the license is included in the [LICENSE](./LICENSE) file.

When incorporating this work into your own project, you must:

- Clearly credit the original authors and provide a link to the original project.
- Preserve all copyright, license, and attribution notices, including this NOTICE file.
- Document any modifications made to the original work.
- Include the full text of the LGPL‑3.0 license with your distribution.
- License modified versions of this project under the LGPL‑3.0 or later.

If this project has been useful to you, please [consider sponsoring its continued development](https://ko-fi.com/thelindat).

---

## Frequently asked questions

### Can I redistribute modified versions of this project?
You may fork, modify, and redistribute this project, provided you comply with the license and preserve the same rights and freedoms for downstream recipients.

### Am I allowed to encrypt this project?
Recipients of this project must receive the complete corresponding source code and be able to install, motifiy, build, and run it. Distributing the project in a form — including through encryption, obfuscation, or other technical measures — that prevents recipients from exercising the rights granted by the license is not permitted.

### Can I sell a modified version of this project?
Commercial distribution is permitted, provided you comply with the terms of the license. However, recipients retain the same rights and freedoms under the license and may freely redistribute modified versions.

---

## Test data derived from ox_lib

`test/parity.golden.json` is a list of public names (exports, import modules, locales, manifest keys, events, convars) extracted from ox_lib 3.39.0 metadata. It is distributed under the same LGPL‑3.0‑or‑later terms as this repository.
