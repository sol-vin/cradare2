# Source-to-Assembly Matching & Line Engine Guide

This document describes the design and usage of `cradare2`'s source line to assembly instruction matching subsystem (`Cradare2::Lines`).

---

## 1. Overview & Objective

When reverse engineering, debugging crashes, or profiling native binaries, a primary bottleneck is correlating a machine instruction address (`0x140001007`) back to the high-level source code line that generated it, and vice versa:

```
Source Line (src/main.cr:42)
  puts "Result: #{val}"
         │
         ▼  (LLVM / Clang Code Generation)
Machine Instructions:
  0x140001007:  48 89 54 24 20    mov qword [rsp + 0x20], rdx
  0x14000100c:  48 8d 0d a0 35 0a lea rcx, [rip + 0xa35a0]
  0x140001013:  e8 68 f2 ff ff    call 0x140000280
```

`Cradare2::Lines` provides a high-performance, bidirectional matching engine that bridges this gap across Windows, Linux, and macOS.

---

## 2. Pluggable Line Resolution (`LineProvider`)

Debug formats vary by compiler and platform:
- **ELF (Linux) / Mach-O (macOS)**: DWARF `.debug_line` tables parsed via radare2's `CLj` command.
- **PE / COFF (Windows)**: CodeView / PDB symbol streams.
- **External Symbolizers**: Host tools such as `llvm-symbolizer`.

`cradare2` unifies these under the `LineProvider` strategy interface (`src/cradare2/lines/line_provider.cr`):

```crystal
module Cradare2
  module Lines
    abstract class LineProvider
      abstract def available? : Bool
      abstract def resolve_all(client : Client) : Array(SourceLocation)
      abstract def resolve_at(client : Client, address : UInt64) : SourceLocation?
    end
  end
end
```

### 2.1 Available Providers
1. **`R2CodelineProvider`**:
   - Queries radare2's internal line table via `CLj` and `idj`.
   - Zero external dependencies.
2. **`LlvmSymbolizerProvider`**:
   - Invokes `llvm-symbolizer` in batch mode against target binaries and PDB files.
   - Ideal for Windows MSVC PDB files and optimized binaries where radare2 DWARF parsing may be incomplete.

### 2.2 Provider Fallback Chain (`LineResolver`)
`LineResolver` automatically walks registered providers in priority order, returning the first successful resolution:

```crystal
resolver = Cradare2::Lines::LineResolver.new(client)
# Attempts R2CodelineProvider first; falls back to LlvmSymbolizerProvider if needed
source_map = resolver.resolve
```

---

## 3. High-Performance Source Map (`SourceMap`)

Once locations are resolved, they are indexed into a `SourceMap` (`src/cradare2/lines/source_map.cr`).

### 3.1 Bidirectional Querying
```crystal
source_map = client.crystal.lines.source_map

# 1. Address to Source Line
if loc = source_map.find_by_address(0x140001007)
  puts "Address 0x140001007 -> #{loc.file}:#{loc.line}"
end

# 2. Source Line to Machine Instructions
instructions = source_map.find_by_line("src/main.cr", 42)
instructions.each do |ins|
  puts "  0x#{ins.address.to_s(16)}: #{ins.opcode} (#{ins.size} bytes)"
end
```

### 3.2 Logarithmic Binary Search (`O(log N)`)
Instructions occupy multi-byte intervals (e.g. `0x140001007` to `0x14000100c` for a 5-byte instruction). A lookup for an interior address like `0x140001009` must resolve to the enclosing instruction.

`SourceMap#find_instruction_containing` implements an $O(\log N)$ binary search algorithm using `bsearch_index`:
```crystal
def find_instruction_containing(address : UInt64) : InstructionMapping?
  idx = @instructions.bsearch_index { |ins| ins.address > address }
  idx = idx ? (idx - 1) : (@instructions.size - 1)
  
  if idx >= 0
    candidate = @instructions[idx]
    return candidate if candidate.contains?(address)
  end
  nil
end
```
This enables instantaneous lookups across binaries with hundreds of thousands of instructions.

---

## 4. Source Code Reading & Path Remapping (`SourceReader`)

Compiling code inside Docker, CI runners, or another directory embeds build-time paths (e.g. `/build/src/main.cr` or `C:\agent\_work\1\s\src\main.cr`) into debug tables.

### 4.1 Configuring Path Remapping
`SourceReader` provides path remapping rules to redirect stale build paths to local source repositories:

```crystal
reader = Cradare2::Lines::SourceReader.new

# Map remote CI path to local repo path
reader.map_path("/build/project", "C:/dev/project")
reader.map_path("/rustc/1.75.0/library", "C:/rust/src")

# Read context window around line 42 with symmetrical 3-line radius
lines = reader.read_context("C:/dev/project/src/main.cr", line: 42, radius: 3)
lines.each do |line_no, text|
  marker = (line_no == 42) ? "▶" : " "
  puts "#{marker} #{line_no.to_s.rjust(4)}: #{text}"
end
```

---

## 5. Interleaved Source & Assembly Listing

Generate compiler-grade interleaved views correlating source lines directly with their generated assembly code:

```crystal
puts client.crystal.lines.interleaved("main")
```

Sample output:
```text
=== File: src/main.cr ===

Line   12: | def calculate(x : Int32)
             | [0x140001000 - 0x140001007, 2 insts, 7 bytes]
  0x140001000  4883ec28          sub rsp, 0x28
  0x140001004  894c2430          mov dword [rsp + 0x30], ecx

Line   13: |   x * 2 + 1
             | [0x140001008 - 0x140001018, 4 insts, 16 bytes]
  0x140001008  8b442430          mov eax, dword [rsp + 0x30]
  0x14000100c  d1e0              shl eax, 1
  0x14000100e  83c001            add eax, 1
  0x140001011  4883c428          add rsp, 0x28
  0x140001015  c3                ret
```

---

## 6. Synchronizing with radare2 (`sync_to_r2`)

Populate radare2's native line tables and disassembly comments so interactive sessions (`pdf`, `v`) display original source lines:

```crystal
# Synchronize both radare2's native CL table and CC disassembly comments
count = client.crystal.lines.sync_to_r2(annotate_comments: true)
puts "Synchronized #{count} lines to radare2 session."
```

Once synchronized, standard radare2 commands (`CL`, `CC`, `pdf`) immediately display source filenames, line numbers, and original Crystal code.
