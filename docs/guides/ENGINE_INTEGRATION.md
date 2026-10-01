# Game Engine & GDExtension Integration Guide (Godot / Lapis)

This guide explains how to use `cradare2` as the native debugging, symbol injection, and crash forensics engine for game engines such as **Godot**, **Lapis (Crystal GDExtension)**, and custom C++/Rust engine runtimes.

---

## 1. The Challenge of Game Engine Debugging

Game engines like Godot present unique reverse engineering and debugging challenges:
1. **Dynamic Extension Boundaries**: The host executable (`godot.exe`), the GDExtension bridge (`lapis.dll` or `crystal_bridge.dll`), and dynamically loaded native plugins run in a single process memory space. When a native crash occurs, identifying *which* module caused the fault is essential.
2. **Dynamic Symbol Dictionaries (ClassDB)**: Godot registers thousands of classes, methods, and properties at runtime rather than in static export tables. Radare2's static analysis does not see these unless they are dynamically injected.
3. **Complex Memory Payloads (Variants)**: Godot's `Variant` type is a 24-byte tagged union (`type_tag`, `flags`, `padding`, `payload`). Decoding Variants directly from memory requires structured type definitions.
4. **Virtual Method Tables (vtables)**: C++ and Crystal GDExtension bindings rely on arrays of function pointers to dispatch virtual methods.

`cradare2` provides first-class primitives specifically designed to solve these four challenges.

---

## 2. Multi-Module Forensics (`client.debug.modules`)

When debugging a crash in Godot, the instruction pointer (`PC`) might be inside the engine, inside the Crystal bridge, or in unmapped memory.

### 2.1 Discovering Loaded Modules
```crystal
require "cradare2"

Cradare2.open("godot.exe", debug: true) do |r2|
  # Retrieve all loaded executable modules and dynamic libraries
  modules = r2.debug.modules
  modules.each do |mod|
    puts "#{mod.name.ljust(20)}: 0x#{mod.base_address.to_s(16)} - 0x#{mod.end_address.to_s(16)} (#{mod.size} bytes)"
    puts "  Path: #{mod.path}"
  end
end
```

### 2.2 Boundary Classification at Crash Time
Given a faulting address (e.g. from CPU registers), determine instantly which component caused the fault:

```crystal
fault_addr = r2.debug.registers.pc

if mod = r2.debug.module_at(fault_addr)
  puts "Crash occurred inside module: #{mod.name}"
  
  case mod.name.downcase
  when .includes?("godot")
    puts "-> Engine internal fault (check engine version or bug reports)"
  when .includes?("lapis"), .includes?("crystal_bridge")
    puts "-> Bridge / GDExtension fault (check Crystal bindings or FFI parameters)"
  else
    puts "-> Third-party library or system DLL: #{mod.name}"
  end
else
  puts "-> Fault occurred in UNMAPPED memory (Null dereference or corrupted function pointer!)"
end
```

### 2.3 Resolving Module Base Address
Query the base address of any loaded module regardless of whether it was referenced by short name or full path:
```crystal
if base = r2.debug.base_address_of("lapis.dll")
  puts "Lapis GDExtension loaded at base: 0x#{base.to_s(16)}"
end
```

---

## 3. ClassDB Symbol Injection with Flag Spaces (`client.flags`)

Godot's `ClassDB` registers methods and properties dynamically. To make these visible in radare2 disassembly and decompilation without polluting global symbols, use **Flag Spaces**.

### 3.1 Isolating Symbols with `flags.space`
```crystal
# Switch to the 'godot' flag space
r2.flags.space("godot")

# Inject Godot core symbols
r2.flags.set("godot.Node2D.set_position", 0x140234000)
r2.flags.set("godot.Node2D.get_position", 0x140234120)

# Switch to the 'lapis' flag space
r2.flags.space("lapis")

# Inject Crystal GDExtension symbols
r2.flags.set("lapis.Player._process", 0x140501000)
r2.flags.set("lapis.Player._ready",   0x140501250)

# List all flag spaces
puts "Active spaces: #{r2.flags.spaces.join(", ")}"
```

### 3.2 High-Throughput Batch Injection
Injecting thousands of ClassDB symbols one-by-one is slow. Use `batch_set` to inject them in a single command pipe:

```crystal
classdb_symbols = {
  "godot.Object.get_class"      => 0x140100000_u64,
  "godot.Object.is_class"       => 0x140100100_u64,
  "godot.RefCounted.reference"  => 0x140100200_u64,
  "godot.RefCounted.unreference"=> 0x140100300_u64,
}

r2.flags.space("godot")
r2.flags.batch_set(classdb_symbols)
```

---

## 4. Structured Variant Decoding with Custom Types (`client.types`)

Godot's `Variant` structure is 24 bytes in 64-bit architectures:
- `type_tag`: 4 bytes (UInt32 enum)
- `flags`: 2 bytes (UInt16)
- `padding`: 2 bytes (UInt16)
- `payload_data`: 16 bytes (two 64-bit words)

### 4.1 Defining the Struct Format
Register the format using radare2's `pf` print format engine:
```crystal
# Define the 24-byte Variant format:
# 'd' = 32-bit int, 'w' = 16-bit word, 'w' = 16-bit word, 'q' = 64-bit quadword, 'q' = 64-bit quadword
r2.types.define_struct("godot_variant", [
  {"d", "type_tag"},
  {"w", "flags"},
  {"w", "padding"},
  {"q", "val0"},
  {"q", "val1"}
])
```

### 4.2 Decoding a Variant from Memory
Read and parse a Variant directly from any memory address into a structured Crystal Hash:

```crystal
variant_addr = 0x140800000_u64
variant = r2.types.print_format("godot_variant", variant_addr)

type_id = variant["type_tag"]?.try(&.as_i64) || 0
puts "Variant Type ID: #{type_id}"
puts "Payload Word 0: 0x#{variant["val0"]?.try(&.as_i64).try(&.to_s(16))}"
puts "Payload Word 1: 0x#{variant["val1"]?.try(&.as_i64).try(&.to_s(16))}"
```

---

## 5. Vtable and String Literal Inspection (`client.memory`)

### 5.1 Inspecting Virtual Method Tables
To inspect a C++ or Crystal class vtable, read an array of 64-bit function pointers using `read_pointer_array`:

```crystal
vtable_address = 0x140700000_u64

# Read 8 consecutive function pointers from the vtable
vtbl_entries = r2.memory.read_pointer_array(vtable_address, count: 8)

vtbl_entries.each_with_index do |fn_ptr, idx|
  # Find matching symbol name for each virtual method pointer
  sym_name = r2.cmd("fd @ 0x#{fn_ptr.to_s(16)}").strip
  puts "vtable[#{idx}] -> 0x#{fn_ptr.to_s(16)} (#{sym_name})"
end
```

### 5.2 Extracting C-Strings (`StringName` & Class Names)
Read null-terminated UTF-8 class names and method signatures:

```crystal
class_name_ptr = 0x140600000_u64
class_name = r2.memory.read_cstring(class_name_ptr, max_len: 128)
puts "Instantiated Godot Class: #{class_name}"
```

---

## 6. Annotating Disassembly with Safe Comments (`client.comments`)

Annotate Godot property names and source line markers without shell escaping bugs using Base64-encoded comments:

```crystal
# Safe against spaces, quotes, and brackets
r2.comments.set(0x140501000, "Godot::Callable#call(args: Array[Variant])")
r2.comments.set(0x140501020, "Field: 'velocity' (Vector2)")

# Query comment
puts r2.comments.get(0x140501000)
# => "Godot::Callable#call(args: Array[Variant])"
```
