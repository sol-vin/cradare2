# CARBON CHANGELOG
## [0.2.21] - 2026-10-01
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite (`7e68d77`)
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer (`0970c53`)
- ✦ **[SECURITY]** add pic? and nx? helpers (`375b517`)
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite (`0efd8c1`)
- ✦ **[TOOLING]** install sol-vin/carbon as automated versioning and changelog system (`887a422`)

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new (`e15224b`)
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit (`aa843e3`)
- ✓ **[TUI]** handle nil sec.perm (`8e2dcdc`)
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction (`a667707`)
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes (`f1c0eae`)
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address (`4cede40`)
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target (`bc35a6d`)

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite (`f7cbd31`)
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools (`fac678c`)
- • format codebase with crystal tool format (`d1b2bb4`)
- • add shards install step to test and docs jobs (`1623e00`)
- • add apt update before install-crystal on Ubuntu runners (`d73ac55`)
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements (`4cbd13b`)
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) (`0b5e17e`)
- • spec (`6918822`)

---
## [0.2.20] - 2026-10-01
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite (`7e68d77`)
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer (`0970c53`)
- ✦ **[SECURITY]** add pic? and nx? helpers (`375b517`)
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite (`0efd8c1`)

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new (`e15224b`)
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit (`aa843e3`)
- ✓ **[TUI]** handle nil sec.perm (`8e2dcdc`)
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction (`a667707`)
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes (`f1c0eae`)
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address (`4cede40`)
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target (`bc35a6d`)

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite (`f7cbd31`)
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools (`fac678c`)
- • format codebase with crystal tool format (`d1b2bb4`)
- • add shards install step to test and docs jobs (`1623e00`)
- • add apt update before install-crystal on Ubuntu runners (`d73ac55`)
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements (`4cbd13b`)
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) (`0b5e17e`)
- • spec (`6918822`)

---
## [0.2.19] - 2026-10-01
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite (`7e68d77`)
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer (`0970c53`)
- ✦ **[SECURITY]** add pic? and nx? helpers (`375b517`)
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite (`0efd8c1`)

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new (`e15224b`)
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit (`aa843e3`)
- ✓ **[TUI]** handle nil sec.perm (`8e2dcdc`)
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction (`a667707`)
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes (`f1c0eae`)
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address (`4cede40`)
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target (`bc35a6d`)

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite (`f7cbd31`)
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools (`fac678c`)
- • format codebase with crystal tool format (`d1b2bb4`)
- • add shards install step to test and docs jobs (`1623e00`)
- • add apt update before install-crystal on Ubuntu runners (`d73ac55`)
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements (`4cbd13b`)
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) (`0b5e17e`)
- • spec (`6918822`)

