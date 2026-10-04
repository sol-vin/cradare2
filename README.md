# cradare2

<!-- carbon:badges -->
[![CI](https://github.com/sol-vin/cradare2/actions/workflows/ci.yml/badge.svg)](https://github.com/sol-vin/cradare2/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blue.svg)](https://sol-vin.github.io/cradare2/)
[![Crystal](https://img.shields.io/badge/crystal-%3E%3D%201.10.0-black.svg)](https://crystal-lang.org)
[![Version](https://img.shields.io/badge/version-0.2.26-blue.svg)](https://github.com/sol-vin/cradare2/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
<!-- /carbon:badges -->

A powerful, idiomatic Crystal framework and high-level DSL for controlling [radare2](https://www.radare.org/) via the `r2pipe` protocol across **Windows**, **Linux**, and **macOS**.

Includes low-level command framing, strongly typed `JSON::Serializable` models, rich DSL modules for binary analysis, memory forensics, disassembly, custom type definitions, Crystal runtime inspection, source-to-assembly correlation, and native debugging (breakpoints, CPU registers, stack unwinding, memory maps, and demangled crash reporting).

---

## In-Depth Guides

- [Architecture & Internals Guide](docs/guides/ARCHITECTURE.md): Transports, client internals, DSL layers, and error model.
- [Game Engine & GDExtension Integration Guide](docs/guides/ENGINE_INTEGRATION.md): Godot & Lapis forensics, ClassDB symbol injection, Variant `pf` decoding, and vtable analysis.
- [Radare2 Plugin Development Guide](docs/guides/PLUGIN_DEVELOPMENT.md): Writing radare2 plugins in Crystal with custom command dispatchers and interactive pipe servers.
- [Source Line Matching & Line Engine Guide](docs/guides/SOURCE_LINE_MATCHING.md): DWARF/PDB line resolution, `llvm-symbolizer`, path remapping, and interleaved listings.
- [Native Debugging, Memory Forensics & Crash Diagnostics Guide](docs/guides/DEBUGGING_AND_FORENSICS.md): Registers, memory classifier, crash diagnosis, stack unwinding, and object inspection.

---

## Features

- **Cross-Platform Transports**:
  - **Subprocess Spawn**: Spawns `r2 -q0` child process with reliable null-byte (`\0`) stream framing and asynchronous fiber timeout enforcement on Windows, Linux, and macOS.
  - **HTTP REST**: Connects to remote radare2 webservers (`http://` or `https://`).
  - **TCP Socket**: Connects directly to remote radare2 TCP instances (`tcp://`).
  - **In-Session (`#!pipe`)**: Connects to the parent radare2 session when run as a script inside radare2 via `R2PIPE_IN`/`R2PIPE_OUT` or `R2PIPE_PATH`.
  - **Deterministic Mocking**: Zero-dependency `MockTransport` for deterministic unit testing.
- **Fluent Configuration (`Cradare2::Options`)**:
  - Fine-grained session setup via options object or builder block (`Cradare2.open(path) { |opts| opts.timeout(10.seconds) }`).
- **Unified Address Representation (`Address`)**:
  - Transparently accepts `UInt64`, `Int64`, `Int32`, or `String` (hex `0x...`, decimal, registers, flags) across all APIs.
- **Multi-Module & Memory Forensics (`r2.debug.modules`)**:
  - Parse loaded PE/ELF/Mach-O binaries, resolve module boundaries, and classify instruction pointers (`module_at`, `base_address_of`).
- **Flags & Flag Spaces (`r2.flags`)**:
  - Fluent flag creation, retrieval, batch setting, and symbol isolation via Flag Spaces (`r2.flags.space("godot")`).
- **Safe Comments DSL (`r2.comments`)**:
  - Automatic Base64 `CCu` encoding and decoding, eliminating shell quoting, whitespace, and injection bugs.
- **Custom Types & Structs (`r2.types`)**:
  - Register C/engine struct formats (`define_struct`) and decode memory into structured Crystal Hashes via `pfj`.
- **Expressive DSLs**:
  - `r2.analyze`: Fluent binary analysis (`all`, `calls`, `functions`, `references`, `autoname`, `preludes`, `emulate`).
  - `r2.disasm`: Disassembly to formatted text, typed instructions, and Ghidra decompilation (`pdc`/`pdg`).
  - `r2.memory`: Direct reading & writing of integers (`u8..u128`, `i8..i128`, `f32..f64`), 128-bit QWORD Emotion Engine SIMD, strings, C-strings (`read_cstring`), typed arrays (`read_pointer32_array`, `read_pointer_array`, `read_u32_array`, `read_f32_array`), hexdump, diffing (`hexdiff`), and pattern searching (`search_hex`).
  - `r2.debug`: Process control, breakpoints, memory classification, crash reporting, and architecture-agnostic registers with first-class x86_64, ARM, and MIPS R5900/I named registers.
- **PlayStation 2 & Citrine Support (`require "cradare2/ps2/citrine"`)**:
  - Privileged GS registers (`PMODE`, `CSR`), drawing registers (`PRIM`, `RGBAQ`, `XYZ2`, `XYZ3`, `TEST_1`, `FRAME_1`, `ZBUF_1`), 128-bit GIFTag decoding, packet dissection, SPRAM canary verification (`0xDEADBEEF`), and EE/IOP disassembler presets.
- **Godot 4 & Lapis Support (`require "cradare2/godot/lapis"`)**:
  - GDExtension library verification (`verify_gdextension`), 24-byte Variant decoding (`read_variant`), object header parsing (`read_object`), vtable symbol resolution (`inspect_vtable`), and crash origin classification (`classify_crash`).
- **In-Memory Buffers (`Cradare2.open_bytes`)**:
  - Disassemble, inspect symbols, and debug ephemeral byte slices with automatic temporary file lifecycle management.
- **Lightweight GDB Remote Serial Protocol Client (`Cradare2::Gdb::Client`)**:
  - Direct socket-level RSP query engine for rapid, zero-overhead memory and register queries against PCSX2, QEMU, or gdbserver stubs during CI audits.
- **Toolchain Doctor Diagnostics (`Cradare2.doctor` & `r2-crystal doctor`)**:
  - Audit radare2 binary, ABI version, disassembler architectures, `llvm-symbolizer`, and Crystal compiler with colored status badges.
- **Extensible Plugin Framework & Interactive Pipe Server**:
  - Modular `Command` classes with configurable prefix (`CommandDispatcher.new(client, prefix: "godot")`), automatic `-j` JSON support, and `Cradare2::Plugin::Server.run`.
- **Source Line to Assembly Matching (`r2.crystal.lines`)**:
  - Pluggable `LineProvider` strategy interface (`R2CodelineProvider`, `LlvmSymbolizerProvider`), path remapping, and $O(\log N)$ binary search instruction matching.

---

## Installation

Add `cradare2` to your `shard.yml`:

```yaml
dependencies:
  cradare2:
    github: sol-vin/cradare2
    branch: master
```

Then run:

```bash
shards install
```

Make sure `radare2` is installed on your system:
- **Windows**: `scoop install radare2` or `choco install radare2`
- **macOS**: `brew install radare2`
- **Linux**: `apt install radare2` or compile from source

---

## Quick Start

```crystal
require "cradare2"

# Open a binary with fluent options
Cradare2.open("my_app.exe") do |r2|
  # Run analysis
  r2.analyze.all

  # Target metadata
  info = r2.info
  puts "Target: #{info.format} #{info.arch} (#{info.bits}-bit) on #{info.os}"

  # Functions
  r2.functions.first(5).each do |fn|
    puts "Function: #{fn.name} @ 0x#{fn.offset.to_s(16)} (#{fn.size} bytes)"
  end

  # Sections
  r2.sections.each do |sec|
    puts "Section #{sec.name}: 0x#{sec.vaddr.to_s(16)} [#{sec.perm}]"
  end

  # Disassemble 5 instructions
  puts r2.disasm.text(5)
end
```

### Fluent Options Builder

```crystal
# Configure timeouts, analysis flags, and write access via builder block
Cradare2.open("my_app.exe") do |opts|
  opts.write_mode
  opts.timeout(15.seconds)
  opts.skip_analysis
end.as(Cradare2::Client)
```

---

## Low-Level API (`cmd`, `cmdj`, `safe_cmdj`, `batch`)

Execute any radare2 command directly:

```crystal
# Raw string output
puts r2.cmd("?e Hello from radare2")

# Dynamic JSON parsing (returns JSON::Any)
json = r2.cmdj("ij")
puts json["bin"]["arch"].as_s

# Type-safe deserialization directly into any JSON::Serializable model
functions = r2.cmdj("aflj", as: Array(Cradare2::Model::Function))

# Safe JSON query (returns nil on parse error or empty output)
info = r2.safe_cmdj("ij", as: Cradare2::Model::BinaryInfo)

# High-throughput batch command execution
r2.batch([
  "s 0x140001000",
  "wx 909090",
  "CC \"Patched with NOPs\""
])

# Profile command latency
r2.on_command do |cmd, elapsed|
  puts "Executed #{cmd} in #{elapsed.total_milliseconds}ms" if elapsed > 50.milliseconds
end
```

---

## High-Level DSL Reference

### Analysis (`r2.analyze`)

```crystal
r2.analyze.all              # "aaa"
r2.analyze.calls            # "aac"
r2.analyze.functions        # "aaf"
r2.analyze.references       # "aar"
r2.analyze.autoname         # "aan"
r2.analyze.preludes         # "aap"
r2.analyze.emulate          # "aae"

# Block form
r2.analyze do |a|
  a.all
  a.calls
end
```

### Memory Manipulation (`r2.memory`)

```crystal
# Reading integers of all widths
u8  = r2.memory.read_u8(0x401000)
u16 = r2.memory.read_u16(0x401000)
u32 = r2.memory.read_u32(0x401000)
u64 = r2.memory.read_u64(0x401000)

# Writing integers
r2.memory.write_u8(0x401000, 0x90_u8)
r2.memory.write_u16(0x401000, 0x1234_u16)
r2.memory.write_u32(0x401000, 0x1337BEEF_u32)
r2.memory.write_u64(0x401000, 0x1122334455667788_u64)

# Reading null-terminated C-strings (auto-trims escaped nulls)
class_name = r2.memory.read_cstring(0x402000, max_len: 128)

# Reading 64-bit pointer arrays (ideal for vtables and function tables)
vtables = r2.memory.read_pointer_array(0x403000, count: 8)

# Pattern Searching
hits = r2.memory.search_bytes(Bytes[0x90, 0x90])
string_hits = r2.memory.search_string("Query")

# Hexdump
puts r2.memory.hexdump(0x401000, size: 64)
```

### Disassembly & Decompilation (`r2.disasm`)

```crystal
# Text disassembly
puts r2.disasm.text(10, at: 0x401000)

# Typed instruction models
instructions = r2.disasm.instructions(10, at: 0x401000)
instructions.each do |ins|
  puts "0x#{ins.offset.to_s(16)}: #{ins.opcode} (type: #{ins.type})"
end

# Decompilation (pdc or Ghidra pdg)
puts r2.disasm.decompile("main")
```

### Flags & Flag Spaces (`r2.flags`)

```crystal
# Switch to 'engine' flag space to isolate symbols
r2.flags.space("engine")

# Set individual flag
r2.flags.set("engine.main_loop", 0x140001000, size: 64)

# Batch set hundreds of symbols in a single pipe write
r2.flags.batch_set({
  "engine.Node2D.position" => 0x140002000_u64,
  "engine.Node2D.rotation" => 0x140002040_u64,
})

# Filter flags matching a pattern
r2.flags.matching(/Node2D/).each do |f|
  puts "#{f.name} @ 0x#{f.offset.to_s(16)}"
end

# Return to root flag space
r2.flags.clear_space
```

### Safe Comments DSL (`r2.comments`)

```crystal
# Annotate code safely using Base64 encoding (immune to quotes, semicolons, and spaces)
r2.comments.set(0x140001000, "Player#_ready(delta: Float64); key=\"val\"")

# Read back comment (auto-decodes Base64 into plain text)
puts r2.comments.get(0x140001000)
# => "Player#_ready(delta: Float64); key=\"val\""

# Clear comment
r2.comments.clear(0x140001000)
```

### Custom Types & Structs (`r2.types`)

```crystal
# Define a 24-byte Godot Variant format ('d' = u32, 'w' = u16, 'q' = u64)
r2.types.define_struct("godot_variant", [
  {"d", "type_tag"},
  {"w", "flags"},
  {"w", "padding"},
  {"q", "val0"},
  {"q", "val1"}
])

# Decode memory directly into a structured Crystal Hash via 'pfj'
variant = r2.types.print_format("godot_variant", 0x140500000)
puts "Type Tag: #{variant["type_tag"]}"
puts "Value 0:  #{variant["val0"]}"
```

### Multi-Module Forensics & Debugging (`r2.debug`)

```crystal
Cradare2.open("godot.exe", debug: true) do |r2|
  r2.debug do |d|
    d.breakpoint("main")
    d.continue

    # Module Forensics
    d.modules.each do |mod|
      puts "#{mod.name}: 0x#{mod.base_address.to_s(16)} - 0x#{mod.end_address.to_s(16)}"
    end

    # Identify module owning the instruction pointer
    if mod = d.module_at(d.registers.pc)
      puts "Currently executing inside: #{mod.name}"
    end

    # Architecture-neutral registers
    puts "PC: 0x#{d.registers.pc.to_s(16)}"
    puts "SP: 0x#{d.registers.sp.to_s(16)}"
    puts "BP: 0x#{d.registers.bp.to_s(16)}"

    # Structured root-cause crash diagnosis
    diagnosis = d.diagnose_crash
    puts "Probable Cause: #{diagnosis.probable_cause}"

    # Full formatted demangled crash report
    puts d.crash_report
  end
end
```

### Crystal Binary & Runtime Inspection (`r2.crystal`)

```crystal
Cradare2.open("my_crystal_app") do |r2|
  # Binary detection
  puts "Crystal Binary: #{r2.crystal.crystal_binary?}"

  # Discover classes and methods
  r2.crystal.classes.each do |cls|
    methods = r2.crystal.methods_for_class(cls)
    puts "#{cls}: #{methods.size} methods"
  end

  # Inspect runtime Crystal String in memory
  str = r2.crystal.read_string(0x1000)
  puts "String: #{str.value} (#{str.bytesize} bytes)"

  # Inspect Crystal Array(T) header
  arr = r2.crystal.read_array_header(0x2000)
  puts "Array size: #{arr.size}, capacity: #{arr.capacity}"

  # Inspect Crystal Slice(T) header
  slice = r2.crystal.read_slice_header(0x3000)
  puts "Slice size: #{slice.size}, read_only: #{slice.read_only?}"

  # Inspect Crystal Fiber
  fiber = r2.crystal.read_fiber(0x4000)
  puts "Fiber stack: 0x#{fiber.stack_address.to_s(16)}"
end
```

### Source Line to Assembly Matching (`r2.crystal.lines`)

```crystal
Cradare2.open("my_app.exe") do |r2|
  # Query source location for an instruction address
  if loc = r2.crystal.lines.at(0x140001007)
    puts "0x140001007 -> #{loc.file}:#{loc.line}"
    puts "Source code: #{loc.source_code}"
  end

  # Find all machine instructions generated for a source line
  instructions = r2.crystal.lines.for_line("src/main.cr", 42)
  instructions.each do |ins|
    puts "  0x#{ins.address.to_s(16)}: #{ins.opcode}"
  end

  # Compiler-grade interleaved source and assembly listing
  puts r2.crystal.lines.interleaved("main")

  # Synchronize line mappings into radare2's native `CL` table & `CC` comments
  count = r2.crystal.lines.sync_to_r2(annotate_comments: true)
  puts "Synchronized #{count} lines to radare2 session."
end
```

---

## Radare2 Plugin & In-Session CLI (`r2-crystal`)

Run standalone against any binary or inside a live radare2 session via `#!pipe r2-crystal`:

```bash
# Standalone CLI
r2-crystal my_app.exe detect
r2-crystal my_app.exe demangle "pdb._2A.add.3C.Int32.3E..3A.Int32"
r2-crystal my_app.exe lines sync
r2-crystal my_app.exe src 0x140001007
r2-crystal my_app.exe asm src/main.cr:42
r2-crystal my_app.exe interleaved main
r2-crystal my_app.exe inspect string 0x1400de0c0
r2-crystal my_app.exe --server # Launch interactive radare2 pipe server
```

Inside radare2:

| Command | Description |
|---|---|
| `crystal help` | Display plugin help and command reference |
| `crystal detect` | Verify if target is a Crystal binary and report entrypoint |
| `crystal info` | Display Crystal runtime information and compiler metadata |
| `crystal demangle <sym>` | Demangle Crystal symbols, operators, and LLVM/MSVC PDB escapes |
| `crystal demangle-all` | Batch demangle all symbols and apply clean names to radare2 (`afn`/`fr`) |
| `crystal lines` | List all discovered source files and mapped line counts |
| `crystal lines sync` | Populate radare2's `CL` line table and annotate `CC` source comments |
| `crystal src <addr>` | Show original source code snippet and context for an address |
| `crystal asm <file:line>` | Show machine instructions generated for a source code line |
| `crystal interleaved <target>` | Generate interleaved source code and assembly listing |
| `crystal classes` | List all detected Crystal classes and modules |
| `crystal methods <class>` | List methods, addresses, and sizes for a given class |
| `crystal inspect string <addr>` | Inspect runtime Crystal `String` struct layout in memory |
| `crystal inspect array <addr>` | Inspect runtime Crystal `Array(T)` header in memory |
| `crystal inspect slice <addr>` | Inspect runtime Crystal `Slice(T)` header in memory |
| `crystal crash` | Generate full demangled crash report with stack unwinding |

---

## Building Custom Radare2 Plugins

External shards and game engines can build specialized command suites with custom prefixes and pipe servers:

```crystal
require "cradare2"

class GodotNodesCommand < Cradare2::Plugin::Command
  def initialize
    super(name: "nodes", summary: "List active Godot nodes", aliases: ["nd"])
  end

  def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
    json ? %({"nodes":42}) : "Active Nodes: 42"
  end
end

client = Cradare2.in_session
dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "godot")
dispatcher.register(GodotNodesCommand.new)

# Run interactive pipe server loop
Cradare2::Plugin::Server.run(dispatcher)
```

---

## Testing

Run the test suite using Crystal's built-in spec runner:

```bash
crystal spec --verbose
```

All **exhaustive specs** run out-of-the-box using the internal `MockTransport` without requiring external network access or dependencies.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
