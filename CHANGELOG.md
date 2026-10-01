# CARBON CHANGELOG
## [0.2.24] - 2026-10-01
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite (`7e68d77`)
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer (`0970c53`)
- ✦ **[SECURITY]** add pic? and nx? helpers (`375b517`)
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite (`0efd8c1`)
- ✦ **[TOOLING]** install sol-vin/carbon as automated versioning and changelog system (`887a422`)
- ✦ **[UPSTREAM]** add process attachment, advanced decompilation, plugin router, and Godot engine forensics (`20e8282`)

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new (`e15224b`)
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit (`aa843e3`)
- ✓ **[TUI]** handle nil sec.perm (`8e2dcdc`)
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction (`a667707`)
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes (`f1c0eae`)
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address (`4cede40`)
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target (`bc35a6d`)

### 📚 Documentation
- 📖 **[CHANGELOG]** update changelog with comprehensive details for lapis upstream features and carbon tooling (`32f3f10`)

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite (`f7cbd31`)
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools (`fac678c`)
- • format codebase with crystal tool format (`d1b2bb4`)
- • add shards install step to test and docs jobs (`1623e00`)
- • add apt update before install-crystal on Ubuntu runners (`d73ac55`)
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements (`4cbd13b`)
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) (`0b5e17e`)
- • spec (`6918822`)
- • add CHANGELOG.md diff verification and support carbon in CI environment (`c40fa45`)

---
## [0.2.23] - 2026-10-01
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite (`7e68d77`)
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer (`0970c53`)
- ✦ **[SECURITY]** add pic? and nx? helpers (`375b517`)
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite (`0efd8c1`)
- ✦ **[TOOLING]** install sol-vin/carbon as automated versioning and changelog system (`887a422`)
- ✦ **[UPSTREAM]** add process attachment, advanced decompilation, plugin router, and Godot engine forensics (`20e8282`)

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new (`e15224b`)
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit (`aa843e3`)
- ✓ **[TUI]** handle nil sec.perm (`8e2dcdc`)
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction (`a667707`)
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes (`f1c0eae`)
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address (`4cede40`)
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target (`bc35a6d`)

### 📚 Documentation
- 📖 **[CHANGELOG]** update changelog with comprehensive details for lapis upstream features and carbon tooling (`32f3f10`)

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite (`f7cbd31`)
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools (`fac678c`)
- • format codebase with crystal tool format (`d1b2bb4`)
- • add shards install step to test and docs jobs (`1623e00`)
- • add apt update before install-crystal on Ubuntu runners (`d73ac55`)
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements (`4cbd13b`)
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) (`0b5e17e`)
- • spec (`6918822`)
- • add CHANGELOG.md diff verification and support carbon in CI environment (`c40fa45`)

---
## [0.2.22] - 2026-10-01
> Comprehensive upstream enhancements supporting lapis, game engine debugging, process attachment, advanced decompilation, composite plugin routing, and sol-vin/carbon automated versioning.
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite (`7e68d77`)
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer (`0970c53`)
- ✦ **[SECURITY]** add pic? and nx? helpers (`375b517`)
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite (`0efd8c1`)
- ✦ **[TOOLING]** install sol-vin/carbon as automated versioning and changelog system with pre-commit hooks and CI/CD verification (`887a422`)
- ✦ **[ATTACH]** add Cradare2.attach(pid) API with fluent builder and block yielding for attaching to running processes (`20e8282`)
- ✦ **[DISASM]** add side_by_side (pdca), source_interleaved (pdls), annotated_source (CLd), and auto-analyzed decompile with disassembly fallback (`20e8282`)
- ✦ **[CRYSTAL]** add Crystal#decompile_method for automated symbol lookup, demangling, and method decompilation (`20e8282`)
- ✦ **[ROUTER]** add Cradare2::Plugin::Router multi-prefix router supporting composite plugin sub-suites (godot, lapis) with colon syntax and unified help (`20e8282`)
- ✦ **[FORENSICS]** add stale vtable detection (Debugger#stale_vtable?, Debugger#find_stale_vtables) across hot-reload module boundaries (`20e8282`)
- ✦ **[GODOT]** add Cradare2::Engine::Godot with GodotObjectHeader, VariantType enum, VariantDecoder with memory cstring dereferencing, and register_godot_formats! (`20e8282`)

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
- • **[CI]** add CHANGELOG.md diff verification, fetch-depth 0, and headless CI support for carbon doctor (`c40fa45`)

---
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

