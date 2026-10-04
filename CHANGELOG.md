# CARBON CHANGELOG
## [0.2.27] - 2026-10-04
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite ([`7e68d77`](https://github.com/sol-vin/cradare2/commit/7e68d77))
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer ([`0970c53`](https://github.com/sol-vin/cradare2/commit/0970c53))
- ✦ **[SECURITY]** add pic? and nx? helpers ([`375b517`](https://github.com/sol-vin/cradare2/commit/375b517))
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite ([`0efd8c1`](https://github.com/sol-vin/cradare2/commit/0efd8c1))
- ✦ **[TOOLING]** install sol-vin/carbon as automated versioning and changelog system ([`887a422`](https://github.com/sol-vin/cradare2/commit/887a422))
- ✦ **[UPSTREAM]** add process attachment, advanced decompilation, plugin router, and Godot engine forensics ([`20e8282`](https://github.com/sol-vin/cradare2/commit/20e8282))
- ✦ **[CLI]** upgrade command outputs with Opal one-shot print features (tables, rules, boxes, badges, markdown) ([`a51ff0f`](https://github.com/sol-vin/cradare2/commit/a51ff0f))
- ✦ **[CORE]** add PS2/Citrine and Godot/Lapis modular extensions, 128-bit memory, MIPS registers, and doctor tool ([`f2caa92`](https://github.com/sol-vin/cradare2/commit/f2caa92))

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new ([`e15224b`](https://github.com/sol-vin/cradare2/commit/e15224b))
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit ([`aa843e3`](https://github.com/sol-vin/cradare2/commit/aa843e3))
- ✓ **[TUI]** handle nil sec.perm ([`8e2dcdc`](https://github.com/sol-vin/cradare2/commit/8e2dcdc))
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction ([`a667707`](https://github.com/sol-vin/cradare2/commit/a667707))
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes ([`f1c0eae`](https://github.com/sol-vin/cradare2/commit/f1c0eae))
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address ([`4cede40`](https://github.com/sol-vin/cradare2/commit/4cede40))
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target ([`bc35a6d`](https://github.com/sol-vin/cradare2/commit/bc35a6d))

### 📚 Documentation
- 📖 **[CHANGELOG]** update changelog with comprehensive details for lapis upstream features and carbon tooling ([`32f3f10`](https://github.com/sol-vin/cradare2/commit/32f3f10))
- 📖 **[CHANGELOG]** update changelog for 0.2.24 Opal CLI print overhaul ([`fee0272`](https://github.com/sol-vin/cradare2/commit/fee0272))

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite ([`f7cbd31`](https://github.com/sol-vin/cradare2/commit/f7cbd31))
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools ([`fac678c`](https://github.com/sol-vin/cradare2/commit/fac678c))
- • format codebase with crystal tool format ([`d1b2bb4`](https://github.com/sol-vin/cradare2/commit/d1b2bb4))
- • add shards install step to test and docs jobs ([`1623e00`](https://github.com/sol-vin/cradare2/commit/1623e00))
- • add apt update before install-crystal on Ubuntu runners ([`d73ac55`](https://github.com/sol-vin/cradare2/commit/d73ac55))
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements ([`4cbd13b`](https://github.com/sol-vin/cradare2/commit/4cbd13b))
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) ([`0b5e17e`](https://github.com/sol-vin/cradare2/commit/0b5e17e))
- • spec ([`6918822`](https://github.com/sol-vin/cradare2/commit/6918822))
- • add CHANGELOG.md diff verification and support carbon in CI environment ([`c40fa45`](https://github.com/sol-vin/cradare2/commit/c40fa45))

---
## [0.2.26] - 2026-10-04
> Modular PlayStation 2 / Citrine (EE MIPS R5900 registers, SPRAM canary verification, 128-bit QWORD SIMD memory primitives, GIFTag packet dissection) and Godot 4 / Lapis GDExtension runtime inspection, scoped flag spaces, batch comments, ScriptBuilder configuration, and Cradare2 Doctor environment diagnostics.
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite ([`7e68d77`](https://github.com/sol-vin/cradare2/commit/7e68d77))
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer ([`0970c53`](https://github.com/sol-vin/cradare2/commit/0970c53))
- ✦ **[SECURITY]** add pic? and nx? helpers ([`375b517`](https://github.com/sol-vin/cradare2/commit/375b517))
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite ([`0efd8c1`](https://github.com/sol-vin/cradare2/commit/0efd8c1))
- ✦ **[TOOLING]** install sol-vin/carbon as automated versioning and changelog system ([`887a422`](https://github.com/sol-vin/cradare2/commit/887a422))
- ✦ **[UPSTREAM]** add process attachment, advanced decompilation, plugin router, and Godot engine forensics ([`20e8282`](https://github.com/sol-vin/cradare2/commit/20e8282))
- ✦ **[CLI]** upgrade command outputs with Opal one-shot print features (tables, rules, boxes, badges, markdown) ([`a51ff0f`](https://github.com/sol-vin/cradare2/commit/a51ff0f))
- ✦ **[CORE]** add PS2/Citrine and Godot/Lapis modular extensions, 128-bit memory, MIPS registers, and doctor tool ([`e3f9190`](https://github.com/sol-vin/cradare2/commit/e3f9190))

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new ([`e15224b`](https://github.com/sol-vin/cradare2/commit/e15224b))
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit ([`aa843e3`](https://github.com/sol-vin/cradare2/commit/aa843e3))
- ✓ **[TUI]** handle nil sec.perm ([`8e2dcdc`](https://github.com/sol-vin/cradare2/commit/8e2dcdc))
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction ([`a667707`](https://github.com/sol-vin/cradare2/commit/a667707))
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes ([`f1c0eae`](https://github.com/sol-vin/cradare2/commit/f1c0eae))
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address ([`4cede40`](https://github.com/sol-vin/cradare2/commit/4cede40))
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target ([`bc35a6d`](https://github.com/sol-vin/cradare2/commit/bc35a6d))

### 📚 Documentation
- 📖 **[CHANGELOG]** update changelog with comprehensive details for lapis upstream features and carbon tooling ([`32f3f10`](https://github.com/sol-vin/cradare2/commit/32f3f10))
- 📖 **[CHANGELOG]** update changelog for 0.2.24 Opal CLI print overhaul ([`fee0272`](https://github.com/sol-vin/cradare2/commit/fee0272))

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite ([`f7cbd31`](https://github.com/sol-vin/cradare2/commit/f7cbd31))
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools ([`fac678c`](https://github.com/sol-vin/cradare2/commit/fac678c))
- • format codebase with crystal tool format ([`d1b2bb4`](https://github.com/sol-vin/cradare2/commit/d1b2bb4))
- • add shards install step to test and docs jobs ([`1623e00`](https://github.com/sol-vin/cradare2/commit/1623e00))
- • add apt update before install-crystal on Ubuntu runners ([`d73ac55`](https://github.com/sol-vin/cradare2/commit/d73ac55))
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements ([`4cbd13b`](https://github.com/sol-vin/cradare2/commit/4cbd13b))
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) ([`0b5e17e`](https://github.com/sol-vin/cradare2/commit/0b5e17e))
- • spec ([`6918822`](https://github.com/sol-vin/cradare2/commit/6918822))
- • add CHANGELOG.md diff verification and support carbon in CI environment ([`c40fa45`](https://github.com/sol-vin/cradare2/commit/c40fa45))

---
## [0.2.25] - 2026-10-01
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite ([`7e68d77`](https://github.com/sol-vin/cradare2/commit/7e68d77))
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer ([`0970c53`](https://github.com/sol-vin/cradare2/commit/0970c53))
- ✦ **[SECURITY]** add pic? and nx? helpers ([`375b517`](https://github.com/sol-vin/cradare2/commit/375b517))
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite ([`0efd8c1`](https://github.com/sol-vin/cradare2/commit/0efd8c1))
- ✦ **[TOOLING]** install sol-vin/carbon as automated versioning and changelog system ([`887a422`](https://github.com/sol-vin/cradare2/commit/887a422))
- ✦ **[UPSTREAM]** add process attachment, advanced decompilation, plugin router, and Godot engine forensics ([`20e8282`](https://github.com/sol-vin/cradare2/commit/20e8282))
- ✦ **[CLI]** upgrade command outputs with Opal one-shot print features (tables, rules, boxes, badges, markdown) ([`a51ff0f`](https://github.com/sol-vin/cradare2/commit/a51ff0f))

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new ([`e15224b`](https://github.com/sol-vin/cradare2/commit/e15224b))
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit ([`aa843e3`](https://github.com/sol-vin/cradare2/commit/aa843e3))
- ✓ **[TUI]** handle nil sec.perm ([`8e2dcdc`](https://github.com/sol-vin/cradare2/commit/8e2dcdc))
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction ([`a667707`](https://github.com/sol-vin/cradare2/commit/a667707))
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes ([`f1c0eae`](https://github.com/sol-vin/cradare2/commit/f1c0eae))
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address ([`4cede40`](https://github.com/sol-vin/cradare2/commit/4cede40))
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target ([`bc35a6d`](https://github.com/sol-vin/cradare2/commit/bc35a6d))

### 📚 Documentation
- 📖 **[CHANGELOG]** update changelog with comprehensive details for lapis upstream features and carbon tooling ([`32f3f10`](https://github.com/sol-vin/cradare2/commit/32f3f10))

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite ([`f7cbd31`](https://github.com/sol-vin/cradare2/commit/f7cbd31))
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools ([`fac678c`](https://github.com/sol-vin/cradare2/commit/fac678c))
- • format codebase with crystal tool format ([`d1b2bb4`](https://github.com/sol-vin/cradare2/commit/d1b2bb4))
- • add shards install step to test and docs jobs ([`1623e00`](https://github.com/sol-vin/cradare2/commit/1623e00))
- • add apt update before install-crystal on Ubuntu runners ([`d73ac55`](https://github.com/sol-vin/cradare2/commit/d73ac55))
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements ([`4cbd13b`](https://github.com/sol-vin/cradare2/commit/4cbd13b))
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) ([`0b5e17e`](https://github.com/sol-vin/cradare2/commit/0b5e17e))
- • spec ([`6918822`](https://github.com/sol-vin/cradare2/commit/6918822))
- • add CHANGELOG.md diff verification and support carbon in CI environment ([`c40fa45`](https://github.com/sol-vin/cradare2/commit/c40fa45))

---
## [0.2.24] - 2026-10-01
> Comprehensive CLI & radare2 command output overhaul leveraging modern Opal one-shot print features (Opal::UI::Table, Opal::UI::Box, Opal::UI::Rule, Opal::UI::Badge, and Opal.render_markdown) with cross-platform Unicode styling and strict JSON mode invariance.
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite ([`7e68d77`](https://github.com/sol-vin/cradare2/commit/7e68d77))
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer ([`0970c53`](https://github.com/sol-vin/cradare2/commit/0970c53))
- ✦ **[SECURITY]** add pic? and nx? helpers ([`375b517`](https://github.com/sol-vin/cradare2/commit/375b517))
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite ([`0efd8c1`](https://github.com/sol-vin/cradare2/commit/0efd8c1))
- ✦ **[TOOLING]** install sol-vin/carbon as automated versioning and changelog system ([`887a422`](https://github.com/sol-vin/cradare2/commit/887a422))
- ✦ **[UPSTREAM]** add process attachment, advanced decompilation, plugin router, and Godot engine forensics ([`20e8282`](https://github.com/sol-vin/cradare2/commit/20e8282))
- ✦ **[FORMATTER]** introduce Cradare2::Util::CLIFormatter wrapping Opal::UI components (Table, Box, Rule, Badge, CodeView, Markdown) with theme safety ([`a51ff0f`](https://github.com/sol-vin/cradare2/commit/a51ff0f))
- ✦ **[ROUTER]** upgrade dispatcher and multi-suite router help screens with styled rules and rounded command tables ([`a51ff0f`](https://github.com/sol-vin/cradare2/commit/a51ff0f))
- ✦ **[COMMANDS]** format Crystal class and method inspection commands (classes, methods, asm, inspect, source) with Opal rounded tables and rule dividers ([`a51ff0f`](https://github.com/sol-vin/cradare2/commit/a51ff0f))
- ✦ **[UI]** render rich markdown crash reports and styled status badges (ERROR, TRACE, CRYSTAL, RENAMED, MAPPED) across CLI tools ([`a51ff0f`](https://github.com/sol-vin/cradare2/commit/a51ff0f))

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new ([`e15224b`](https://github.com/sol-vin/cradare2/commit/e15224b))
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit ([`aa843e3`](https://github.com/sol-vin/cradare2/commit/aa843e3))
- ✓ **[TUI]** handle nil sec.perm ([`8e2dcdc`](https://github.com/sol-vin/cradare2/commit/8e2dcdc))
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction ([`a667707`](https://github.com/sol-vin/cradare2/commit/a667707))
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes ([`f1c0eae`](https://github.com/sol-vin/cradare2/commit/f1c0eae))
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address ([`4cede40`](https://github.com/sol-vin/cradare2/commit/4cede40))
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target ([`bc35a6d`](https://github.com/sol-vin/cradare2/commit/bc35a6d))

### 📚 Documentation
- 📖 **[CHANGELOG]** update changelog with comprehensive details for lapis upstream features and carbon tooling ([`32f3f10`](https://github.com/sol-vin/cradare2/commit/32f3f10))

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite ([`f7cbd31`](https://github.com/sol-vin/cradare2/commit/f7cbd31))
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools ([`fac678c`](https://github.com/sol-vin/cradare2/commit/fac678c))
- • format codebase with crystal tool format ([`d1b2bb4`](https://github.com/sol-vin/cradare2/commit/d1b2bb4))
- • add shards install step to test and docs jobs ([`1623e00`](https://github.com/sol-vin/cradare2/commit/1623e00))
- • add apt update before install-crystal on Ubuntu runners ([`d73ac55`](https://github.com/sol-vin/cradare2/commit/d73ac55))
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements ([`4cbd13b`](https://github.com/sol-vin/cradare2/commit/4cbd13b))
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) ([`0b5e17e`](https://github.com/sol-vin/cradare2/commit/0b5e17e))
- • spec ([`6918822`](https://github.com/sol-vin/cradare2/commit/6918822))
- • add CHANGELOG.md diff verification and support carbon in CI environment ([`c40fa45`](https://github.com/sol-vin/cradare2/commit/c40fa45))

---
## [0.2.23] - 2026-10-01
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite ([`7e68d77`](https://github.com/sol-vin/cradare2/commit/7e68d77))
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer ([`0970c53`](https://github.com/sol-vin/cradare2/commit/0970c53))
- ✦ **[SECURITY]** add pic? and nx? helpers ([`375b517`](https://github.com/sol-vin/cradare2/commit/375b517))
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite ([`0efd8c1`](https://github.com/sol-vin/cradare2/commit/0efd8c1))
- ✦ **[TOOLING]** install sol-vin/carbon as automated versioning and changelog system ([`887a422`](https://github.com/sol-vin/cradare2/commit/887a422))
- ✦ **[UPSTREAM]** add process attachment, advanced decompilation, plugin router, and Godot engine forensics ([`20e8282`](https://github.com/sol-vin/cradare2/commit/20e8282))

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new ([`e15224b`](https://github.com/sol-vin/cradare2/commit/e15224b))
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit ([`aa843e3`](https://github.com/sol-vin/cradare2/commit/aa843e3))
- ✓ **[TUI]** handle nil sec.perm ([`8e2dcdc`](https://github.com/sol-vin/cradare2/commit/8e2dcdc))
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction ([`a667707`](https://github.com/sol-vin/cradare2/commit/a667707))
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes ([`f1c0eae`](https://github.com/sol-vin/cradare2/commit/f1c0eae))
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address ([`4cede40`](https://github.com/sol-vin/cradare2/commit/4cede40))
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target ([`bc35a6d`](https://github.com/sol-vin/cradare2/commit/bc35a6d))

### 📚 Documentation
- 📖 **[CHANGELOG]** update changelog with comprehensive details for lapis upstream features and carbon tooling ([`32f3f10`](https://github.com/sol-vin/cradare2/commit/32f3f10))

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite ([`f7cbd31`](https://github.com/sol-vin/cradare2/commit/f7cbd31))
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools ([`fac678c`](https://github.com/sol-vin/cradare2/commit/fac678c))
- • format codebase with crystal tool format ([`d1b2bb4`](https://github.com/sol-vin/cradare2/commit/d1b2bb4))
- • add shards install step to test and docs jobs ([`1623e00`](https://github.com/sol-vin/cradare2/commit/1623e00))
- • add apt update before install-crystal on Ubuntu runners ([`d73ac55`](https://github.com/sol-vin/cradare2/commit/d73ac55))
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements ([`4cbd13b`](https://github.com/sol-vin/cradare2/commit/4cbd13b))
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) ([`0b5e17e`](https://github.com/sol-vin/cradare2/commit/0b5e17e))
- • spec ([`6918822`](https://github.com/sol-vin/cradare2/commit/6918822))
- • add CHANGELOG.md diff verification and support carbon in CI environment ([`c40fa45`](https://github.com/sol-vin/cradare2/commit/c40fa45))

---
## [0.2.22] - 2026-10-01
> Comprehensive upstream enhancements supporting lapis, game engine debugging, process attachment, advanced decompilation, composite plugin routing, and sol-vin/carbon automated versioning.
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite ([`7e68d77`](https://github.com/sol-vin/cradare2/commit/7e68d77))
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer ([`0970c53`](https://github.com/sol-vin/cradare2/commit/0970c53))
- ✦ **[SECURITY]** add pic? and nx? helpers ([`375b517`](https://github.com/sol-vin/cradare2/commit/375b517))
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite ([`0efd8c1`](https://github.com/sol-vin/cradare2/commit/0efd8c1))
- ✦ **[TOOLING]** install sol-vin/carbon as automated versioning and changelog system with pre-commit hooks and CI/CD verification ([`887a422`](https://github.com/sol-vin/cradare2/commit/887a422))
- ✦ **[ATTACH]** add Cradare2.attach(pid) API with fluent builder and block yielding for attaching to running processes ([`20e8282`](https://github.com/sol-vin/cradare2/commit/20e8282))
- ✦ **[DISASM]** add side_by_side (pdca), source_interleaved (pdls), annotated_source (CLd), and auto-analyzed decompile with disassembly fallback ([`20e8282`](https://github.com/sol-vin/cradare2/commit/20e8282))
- ✦ **[CRYSTAL]** add Crystal#decompile_method for automated symbol lookup, demangling, and method decompilation ([`20e8282`](https://github.com/sol-vin/cradare2/commit/20e8282))
- ✦ **[ROUTER]** add Cradare2::Plugin::Router multi-prefix router supporting composite plugin sub-suites (godot, lapis) with colon syntax and unified help ([`20e8282`](https://github.com/sol-vin/cradare2/commit/20e8282))
- ✦ **[FORENSICS]** add stale vtable detection (Debugger#stale_vtable?, Debugger#find_stale_vtables) across hot-reload module boundaries ([`20e8282`](https://github.com/sol-vin/cradare2/commit/20e8282))
- ✦ **[GODOT]** add Cradare2::Engine::Godot with GodotObjectHeader, VariantType enum, VariantDecoder with memory cstring dereferencing, and register_godot_formats! ([`20e8282`](https://github.com/sol-vin/cradare2/commit/20e8282))

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new ([`e15224b`](https://github.com/sol-vin/cradare2/commit/e15224b))
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit ([`aa843e3`](https://github.com/sol-vin/cradare2/commit/aa843e3))
- ✓ **[TUI]** handle nil sec.perm ([`8e2dcdc`](https://github.com/sol-vin/cradare2/commit/8e2dcdc))
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction ([`a667707`](https://github.com/sol-vin/cradare2/commit/a667707))
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes ([`f1c0eae`](https://github.com/sol-vin/cradare2/commit/f1c0eae))
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address ([`4cede40`](https://github.com/sol-vin/cradare2/commit/4cede40))
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target ([`bc35a6d`](https://github.com/sol-vin/cradare2/commit/bc35a6d))

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite ([`f7cbd31`](https://github.com/sol-vin/cradare2/commit/f7cbd31))
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools ([`fac678c`](https://github.com/sol-vin/cradare2/commit/fac678c))
- • format codebase with crystal tool format ([`d1b2bb4`](https://github.com/sol-vin/cradare2/commit/d1b2bb4))
- • add shards install step to test and docs jobs ([`1623e00`](https://github.com/sol-vin/cradare2/commit/1623e00))
- • add apt update before install-crystal on Ubuntu runners ([`d73ac55`](https://github.com/sol-vin/cradare2/commit/d73ac55))
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements ([`4cbd13b`](https://github.com/sol-vin/cradare2/commit/4cbd13b))
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) ([`0b5e17e`](https://github.com/sol-vin/cradare2/commit/0b5e17e))
- • spec ([`6918822`](https://github.com/sol-vin/cradare2/commit/6918822))
- • **[CI]** add CHANGELOG.md diff verification, fetch-depth 0, and headless CI support for carbon doctor ([`c40fa45`](https://github.com/sol-vin/cradare2/commit/c40fa45))

---
## [0.2.21] - 2026-10-01
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite ([`7e68d77`](https://github.com/sol-vin/cradare2/commit/7e68d77))
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer ([`0970c53`](https://github.com/sol-vin/cradare2/commit/0970c53))
- ✦ **[SECURITY]** add pic? and nx? helpers ([`375b517`](https://github.com/sol-vin/cradare2/commit/375b517))
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite ([`0efd8c1`](https://github.com/sol-vin/cradare2/commit/0efd8c1))
- ✦ **[TOOLING]** install sol-vin/carbon as automated versioning and changelog system ([`887a422`](https://github.com/sol-vin/cradare2/commit/887a422))

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new ([`e15224b`](https://github.com/sol-vin/cradare2/commit/e15224b))
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit ([`aa843e3`](https://github.com/sol-vin/cradare2/commit/aa843e3))
- ✓ **[TUI]** handle nil sec.perm ([`8e2dcdc`](https://github.com/sol-vin/cradare2/commit/8e2dcdc))
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction ([`a667707`](https://github.com/sol-vin/cradare2/commit/a667707))
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes ([`f1c0eae`](https://github.com/sol-vin/cradare2/commit/f1c0eae))
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address ([`4cede40`](https://github.com/sol-vin/cradare2/commit/4cede40))
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target ([`bc35a6d`](https://github.com/sol-vin/cradare2/commit/bc35a6d))

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite ([`f7cbd31`](https://github.com/sol-vin/cradare2/commit/f7cbd31))
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools ([`fac678c`](https://github.com/sol-vin/cradare2/commit/fac678c))
- • format codebase with crystal tool format ([`d1b2bb4`](https://github.com/sol-vin/cradare2/commit/d1b2bb4))
- • add shards install step to test and docs jobs ([`1623e00`](https://github.com/sol-vin/cradare2/commit/1623e00))
- • add apt update before install-crystal on Ubuntu runners ([`d73ac55`](https://github.com/sol-vin/cradare2/commit/d73ac55))
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements ([`4cbd13b`](https://github.com/sol-vin/cradare2/commit/4cbd13b))
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) ([`0b5e17e`](https://github.com/sol-vin/cradare2/commit/0b5e17e))
- • spec ([`6918822`](https://github.com/sol-vin/cradare2/commit/6918822))

---
## [0.2.20] - 2026-10-01
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite ([`7e68d77`](https://github.com/sol-vin/cradare2/commit/7e68d77))
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer ([`0970c53`](https://github.com/sol-vin/cradare2/commit/0970c53))
- ✦ **[SECURITY]** add pic? and nx? helpers ([`375b517`](https://github.com/sol-vin/cradare2/commit/375b517))
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite ([`0efd8c1`](https://github.com/sol-vin/cradare2/commit/0efd8c1))

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new ([`e15224b`](https://github.com/sol-vin/cradare2/commit/e15224b))
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit ([`aa843e3`](https://github.com/sol-vin/cradare2/commit/aa843e3))
- ✓ **[TUI]** handle nil sec.perm ([`8e2dcdc`](https://github.com/sol-vin/cradare2/commit/8e2dcdc))
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction ([`a667707`](https://github.com/sol-vin/cradare2/commit/a667707))
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes ([`f1c0eae`](https://github.com/sol-vin/cradare2/commit/f1c0eae))
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address ([`4cede40`](https://github.com/sol-vin/cradare2/commit/4cede40))
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target ([`bc35a6d`](https://github.com/sol-vin/cradare2/commit/bc35a6d))

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite ([`f7cbd31`](https://github.com/sol-vin/cradare2/commit/f7cbd31))
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools ([`fac678c`](https://github.com/sol-vin/cradare2/commit/fac678c))
- • format codebase with crystal tool format ([`d1b2bb4`](https://github.com/sol-vin/cradare2/commit/d1b2bb4))
- • add shards install step to test and docs jobs ([`1623e00`](https://github.com/sol-vin/cradare2/commit/1623e00))
- • add apt update before install-crystal on Ubuntu runners ([`d73ac55`](https://github.com/sol-vin/cradare2/commit/d73ac55))
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements ([`4cbd13b`](https://github.com/sol-vin/cradare2/commit/4cbd13b))
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) ([`0b5e17e`](https://github.com/sol-vin/cradare2/commit/0b5e17e))
- • spec ([`6918822`](https://github.com/sol-vin/cradare2/commit/6918822))

---
## [0.2.19] - 2026-10-01
### ✨ Features & Improvements
- ✦ add Crystal runtime inspection, CI matrix, docs deployment, and expanded test suite ([`7e68d77`](https://github.com/sol-vin/cradare2/commit/7e68d77))
- ✦ add Xref, SecurityInfo, MemoryClassifier, CrashDiagnosis, and interactive Opal TEA Explorer ([`0970c53`](https://github.com/sol-vin/cradare2/commit/0970c53))
- ✦ **[SECURITY]** add pic? and nx? helpers ([`375b517`](https://github.com/sol-vin/cradare2/commit/375b517))
- ✦ **[PLUGIN]** add radare2 Crystal plugin, source-to-asm matching, and massive test suite ([`0efd8c1`](https://github.com/sol-vin/cradare2/commit/0efd8c1))

### 🐛 Bug Fixes
- ✓ **[TUI]** use mouse_enabled parameter in Program.new ([`e15224b`](https://github.com/sol-vin/cradare2/commit/e15224b))
- ✓ **[TUI]** return Opal::TEA::Cmd.none and Cmd.quit ([`aa843e3`](https://github.com/sol-vin/cradare2/commit/aa843e3))
- ✓ **[TUI]** handle nil sec.perm ([`8e2dcdc`](https://github.com/sol-vin/cradare2/commit/8e2dcdc))
- ✓ **[CLASSIFIER]** support cross-platform path separators for module extraction ([`a667707`](https://github.com/sol-vin/cradare2/commit/a667707))
- ✓ **[LINES]** ensure safe_r2_path strips drive colon across differing drives and OSes ([`f1c0eae`](https://github.com/sol-vin/cradare2/commit/f1c0eae))
- ✓ **[DEBUGGER]** normalize cross-platform paths when grouping modules and resolving base address ([`4cede40`](https://github.com/sol-vin/cradare2/commit/4cede40))
- ✓ **[SPEC]** replace hardware watchpoint with software breakpoint in live r2 malloc target ([`bc35a6d`](https://github.com/sol-vin/cradare2/commit/bc35a6d))

### 🛠️ Chores & Tooling
- • Initial commit of cradare2 library and test suite ([`f7cbd31`](https://github.com/sol-vin/cradare2/commit/f7cbd31))
- • Decouple lapis-specific logic; generalize native crash diagnostics and symbol query tools ([`fac678c`](https://github.com/sol-vin/cradare2/commit/fac678c))
- • format codebase with crystal tool format ([`d1b2bb4`](https://github.com/sol-vin/cradare2/commit/d1b2bb4))
- • add shards install step to test and docs jobs ([`1623e00`](https://github.com/sol-vin/cradare2/commit/1623e00))
- • add apt update before install-crystal on Ubuntu runners ([`d73ac55`](https://github.com/sol-vin/cradare2/commit/d73ac55))
- ✦ modular command registry, line providers, memory forensics, and Godot/Lapis enhancements ([`4cbd13b`](https://github.com/sol-vin/cradare2/commit/4cbd13b))
- • docs & tests: add 5 deep-dive guides, 5 executable examples, and 9 exhaustive test suites (337 passing specs) ([`0b5e17e`](https://github.com/sol-vin/cradare2/commit/0b5e17e))
- • spec ([`6918822`](https://github.com/sol-vin/cradare2/commit/6918822))

