# cradare2

A powerful, idiomatic Crystal library and high-level DSL for controlling [radare2](https://www.radare.org/) via the `r2pipe` protocol across **Windows**, **Linux**, and **macOS**.

Includes low-level command framing, strongly typed `JSON::Serializable` models, rich DSL modules for analysis, memory, and debugging, and dedicated diagnostic tools specifically tailored for **`lapis`** (Godot 4 GDExtension binaries written in Crystal).

---

## Features

- **Cross-Platform Transports**:
  - **Subprocess Spawn**: Spawns `r2 -q0` child process with reliable null-byte (`\0`) stream framing on Windows, Linux, and macOS.
  - **HTTP REST**: Connects to remote radare2 webservers (`http://` or `https://`).
  - **TCP Socket**: Connects directly to remote radare2 TCP instances (`tcp://`).
  - **In-Session (`#!pipe`)**: Seamlessly connects to the parent radare2 session when run as a script inside radare2 via `R2PIPE_IN`/`R2PIPE_OUT` or `R2PIPE_PATH`.
  - **Deterministic Mocking**: Zero-dependency `MockTransport` for deterministic unit testing.
- **Strongly Typed Models**:
  - Complete `JSON::Serializable` models for binary metadata (`ij`), functions (`aflj`), symbols (`isj`), exports (`iEj`), imports (`iij`), sections (`iSj`), strings (`izj`), disassembly (`pdj`), CPU registers (`drj`), breakpoints (`dbj`), backtraces (`dbtj`), memory maps (`dmj`), and threads (`dptj`).
  - Dynamic JSON fallback (`r2.cmdj(...)`) returning `JSON::Any`.
- **Expressive DSL**:
  - `r2.analyze`: Fluent binary analysis (`all`, `calls`, `functions`, `references`, `autoname`, etc.).
  - `r2.disasm`: Disassembly to formatted text, typed instructions, and decompilation (`pdc`/`pdg`).
  - `r2.memory`: Direct reading & writing of bytes, integers, strings, hexdumps, and pattern searching.
  - `r2.debug`: Process execution control (`continue`, `step`, `step_over`, `step_until`), breakpoints, registers, and memory maps.
- **Lapis & Godot 4 GDExtension Tools**:
  - `r2.lapis.verify_gdextension`: Validates exported entrypoints (`lapis_gdextension_entry`, `godot_gdextension_entry`, etc.).
  - `r2.lapis.find_crystal_symbols`: Identifies and demangles Crystal methods and types.
  - `r2.lapis.find_godot_bindings`: Maps Godot C API function imports.
  - `r2.lapis.inspect_crash`: Diagnoses access violations, crash offsets, faulting memory regions, and demangled backtraces.

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
R2.open("my_game/bin/game.dll") do |r2|
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

# Writing
r2.memory.write(0x401000, Bytes[0x90, 0x90, 0xCC, 0xC3])
r2.memory.write_string(0x402000, "Godot Engine")
r2.memory.write_u32(0x401000, 0x1337BEEF_u32)

# Pattern Searching
hits = r2.memory.search_bytes(Bytes[0x90, 0x90])
string_hits = r2.memory.search_string("Lapis")

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
R2.open("my_game.exe", debug: true) do |r2|
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

---

## Debugging Lapis / Godot 4 GDExtensions

When developing Godot 4 games with Crystal and Lapis, debugging native crashes and verifying GDExtension DLLs is critical:

```crystal
require "cradare2"

R2.open("my_game/bin/game.dll") do |r2|
  r2.analyze.all

  # 1. Verify GDExtension export symbols
  check = r2.lapis.verify_gdextension
  if check.valid
    puts "GDExtension entrypoint verified: #{check.entrypoint_name}"
  else
    puts "GDExtension validation failed: #{check.warnings.join(", ")}"
  end

  # 2. Demangle Crystal types & methods
  r2.lapis.find_crystal_symbols.each do |sym|
    puts "Crystal method: #{sym.display_name} @ 0x#{sym.offset.to_s(16)}"
  end

  # 3. Discover Godot C API imports
  r2.lapis.find_godot_bindings.each do |imp|
    puts "Godot API: #{imp.name}"
  end
end
```

### Crash Inspection

If Godot crashes inside your extension, `r2.lapis.inspect_crash` formats a full diagnostic report:

```crystal
report = r2.lapis.inspect_crash
puts report
```

Sample output:
```text
=== Lapis / GDExtension Crash Diagnostic ===
Crash PC (Instruction Pointer): 0x401032
Stack Pointer: 0x20c3c50718
Base Pointer:  0x20c3c50748

Active Function: MyGame::Player#_process:Float64
Faulting Region: game.dll (0x400000 - 0x410000, -r-x)

Registers:
  RAX: 0x401000  RBX: 0x64  RCX: 0x0
  RDX: 0x409000  RSI: 0x3e8  RDI: 0x7d0
  R8:  0x1   R9:  0x2   R10: 0x3

Demangled Backtrace:
  #0 0x401032 in MyGame::Player#_process:Float64
  #1 0x4010a0 in lapis_gdextension_entry
```

---

## Testing

Run the test suite using Crystal's built-in spec runner:

```bash
crystal spec --verbose
```

All specs run out-of-the-box using the internal `MockTransport` without requiring external network access.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
