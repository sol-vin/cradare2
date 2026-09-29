# cradare2

[![CI](https://github.com/sol-vin/cradare2/actions/workflows/ci.yml/badge.svg)](https://github.com/sol-vin/cradare2/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blue.svg)](https://sol-vin.github.io/cradare2/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A powerful, idiomatic Crystal library and high-level DSL for controlling [radare2](https://www.radare.org/) via the `r2pipe` protocol across **Windows**, **Linux**, and **macOS**.

Includes low-level command framing, strongly typed `JSON::Serializable` models, rich DSL modules for binary analysis, memory manipulation, disassembly, Crystal runtime inspection, and native debugging (breakpoints, CPU registers, stack unwinding, memory maps, and demangled crash reporting).

---

## Features

- **Cross-Platform Transports**:
  - **Subprocess Spawn**: Spawns `r2 -q0` child process with reliable null-byte (`\0`) stream framing on Windows, Linux, and macOS.
  - **HTTP REST**: Connects to remote radare2 webservers (`http://` or `https://`).
  - **TCP Socket**: Connects directly to remote radare2 TCP instances (`tcp://`).
  - **In-Session (`#!pipe`)**: Connects to the parent radare2 session when run as a script inside radare2 via `R2PIPE_IN`/`R2PIPE_OUT` or `R2PIPE_PATH`.
  - **Deterministic Mocking**: Zero-dependency `MockTransport` for deterministic unit testing.
- **Strongly Typed Models**:
  - Complete `JSON::Serializable` models for binary metadata (`ij`), functions (`aflj`), symbols (`isj`), exports (`iEj`), imports (`iij`), sections (`iSj`), strings (`izj`), disassembly (`pdj`), CPU registers (`drj`), breakpoints (`dbj`), backtraces (`dbtj`), memory maps (`dmj`), and threads (`dptj`).
  - Dynamic JSON fallback (`r2.cmdj(...)`) returning `JSON::Any`.
- **Expressive DSL**:
  - `r2.analyze`: Fluent binary analysis (`all`, `calls`, `functions`, `references`, `autoname`, `preludes`, `emulate`).
  - `r2.disasm`: Disassembly to formatted text, typed instructions, and decompilation (`pdc`/`pdg`).
  - `r2.memory`: Direct reading & writing of bytes, integers, strings, hexdumps, and pattern searching.
  - `r2.debug`: Process execution control (`continue`, `step`, `step_over`, `step_until`), breakpoints, registers, memory maps, and demangled crash reporting.
- **Symbol & Function Querying**:
  - Convenient filters: `symbols_matching`, `functions_matching`, `exports_matching`, `imports_matching`, `strings_matching`.
  - Multi-language symbol demangler supporting Crystal (`*Namespace::Class#method:Type`), C++ (Itanium/MSVC), and Rust.

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

# Open a binary (spawns r2 -q0 under the hood)
R2.open("my_app.exe") do |r2|
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

---

## Low-Level API (`cmd` and `cmdj`)

You can execute any radare2 command directly:

```crystal
# Raw string output
puts r2.cmd("?e Hello from radare2")

# Dynamic JSON parsing (returns JSON::Any)
json = r2.cmdj("ij")
puts json["bin"]["arch"].as_s

# Type-safe deserialization directly into any JSON::Serializable model
functions = r2.cmdj("aflj", as: Array(Cradare2::Model::Function))
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
# Reading
bytes = r2.memory.read(0x401000, size: 16)
str = r2.memory.read_string(0x402000)
u32 = r2.memory.read_u32(0x401000)
u64 = r2.memory.read_u64(0x401000)

# Writing
r2.memory.write(0x401000, Bytes[0x90, 0x90, 0xCC, 0xC3])
r2.memory.write_string(0x402000, "Hello World")
r2.memory.write_u32(0x401000, 0x1337BEEF_u32)
r2.memory.write_u64(0x401000, 0x1122334455667788_u64)

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

### Debugger (`r2.debug`)

```crystal
R2.open("my_app.exe", debug: true) do |r2|
  r2.debug do |d|
    d.breakpoint("main")
    d.continue

    # Architecture-neutral registers
    puts "RIP / PC: 0x#{d.registers.pc.to_s(16)}"
    puts "RSP / SP: 0x#{d.registers.sp.to_s(16)}"

    # Specific registers
    puts "RAX: 0x#{d.registers.rax.to_s(16)}"

    # Call stack / Backtrace
    d.backtrace.each do |frame|
      puts "##{frame.frame} 0x#{frame.pc.to_s(16)} in #{frame.function}"
    end

    # Step instruction
    d.step
  end
end
```

### Native Crash Diagnostics

When inspecting or debugging a crashed binary or DLL, `r2.debug.crash_report` formats a comprehensive diagnostic summary:

```crystal
report = r2.debug.crash_report
puts report
```

Sample output:
```text
=== Native Crash Diagnostic Report ===
Crash PC (Instruction Pointer): 0x401032
Stack Pointer (SP):             0x20c3c50718
Base/Frame Pointer (BP):        0x20c3c50748

Active Function: MyGame::Player#_process:Float64
Faulting Region: game.dll (0x400000 - 0x410000, -r-x)

Registers:
  RAX: 0x401000  RBX: 0x64  RCX: 0x0
  RDX: 0x409000  RSI: 0x3e8  RDI: 0x7d0
  R8:  0x1   R9:  0x2   R10: 0x3

Call Stack (Demangled):
  #0 0x401032 in MyGame::Player#_process:Float64
  #1 0x4010a0 in entry_point
```

### Crystal Binary & Runtime Inspection (`r2.crystal`)

`cradare2` includes first-class tools for analyzing Crystal binaries, parsing mangled method signatures, and inspecting Crystal object layouts directly in memory:

```crystal
R2.open("my_crystal_app") do |r2|
  r2.analyze.all

  # Detect Crystal binaries and locate entrypoint
  if r2.crystal.crystal_binary?
    puts "Entrypoint: 0x#{r2.crystal.entrypoint.try(&.to_s(16))}"
  end

  # Discover all Crystal classes and their analyzed methods
  r2.crystal.classes.each do |cls|
    methods = r2.crystal.methods_for_class(cls)
    puts "Class #{cls}: #{methods.size} methods"
  end

  # Inspect runtime Crystal String in memory (offset 0: type_id, 4: bytesize, 8: length, 12: UTF-8 bytes)
  str = r2.crystal.read_string(0x1000)
  puts "String value: #{str.value} (length: #{str.length}, bytesize: #{str.bytesize})"

  # Inspect Crystal Array(T) header (type_id, size, capacity, buffer pointer)
  arr = r2.crystal.read_array_header(0x2000)
  puts "Array size: #{arr.size}, capacity: #{arr.capacity}, buffer: 0x#{arr.buffer_address.to_s(16)}"

  # Inspect Crystal Slice(T) header (size, read_only, pointer)
  slice = r2.crystal.read_slice_header(0x3000)
  puts "Slice size: #{slice.size}, read_only: #{slice.read_only?}"

  # Crystal-specific demangled crash report with stack trace and registers
  puts r2.crystal.crash_report
end
```

---

## Building Custom Debuggers with `cradare2`

`cradare2` is designed to serve as the low-level native debugger backend for higher-level frameworks and extensions (such as game engines, GDExtensions, or language runtimes).

External shards can easily build specialized inspectors or runners on top of `cradare2`:

```crystal
require "cradare2"

class MyFrameworkDebugger
  def initialize(@target : String)
    @r2 = Cradare2.open(@target, debug: true)
  end

  def watch_entrypoint(entry_symbol : String)
    @r2.debug.breakpoint(entry_symbol)
    @r2.debug.continue
  end

  def handle_crash
    puts @r2.debug.crash_report
  end

  def close
    @r2.close
  end
end
```

---

## Testing

Run the test suite using Crystal's built-in spec runner:

```bash
crystal spec --verbose
```

All 68 specs run out-of-the-box using the internal `MockTransport` without requiring external network access.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
