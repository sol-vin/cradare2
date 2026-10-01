# Native Debugging, Memory Forensics & Crash Diagnostics Guide

This document describes the native debugging, crash diagnosis, and runtime memory inspection capabilities provided by `cradare2`.

---

## 1. Process Lifecycle & Execution Control (`client.debug`)

To attach to a running process or launch an executable in debugger mode, pass `debug: true`:

```crystal
require "cradare2"

Cradare2.open("my_app.exe", debug: true) do |r2|
  r2.debug do |d|
    # Set breakpoint at main or entry
    d.breakpoint("main")

    # Continue execution until breakpoint is reached
    d.continue

    puts "Current Execution Status: #{d.status}"
    puts "PID: #{d.pid}"

    # Single-step one instruction
    d.step

    # Step over function calls
    d.step_over

    # Step until target address or condition
    d.step_until(0x140002500)
  end
end
```

---

## 2. Architecture-Neutral CPU Registers

Accessing CPU registers across architectures (x86_64, ARM64, i386) is unified via `Registers`:

```crystal
regs = r2.debug.registers

# Universal Architecture-Neutral Pointers
puts "PC (Instruction Pointer): 0x#{regs.pc.to_s(16)}"
puts "SP (Stack Pointer):       0x#{regs.sp.to_s(16)}"
puts "BP (Base/Frame Pointer):  0x#{regs.bp.to_s(16)}"

# Specific 64-bit Registers
puts "RAX: 0x#{regs.rax.to_s(16)}"
puts "RBX: 0x#{regs.rbx.to_s(16)}"
puts "RCX: 0x#{regs.rcx.to_s(16)}"
puts "RDX: 0x#{regs.rdx.to_s(16)}"

# Flags
puts "Flags Register: 0x#{regs.flags.to_s(16)}"
```

---

## 3. Memory Classification & Boundary Forensics

Determining whether a raw register pointer points to the stack, the heap, executable code, or an unmapped memory region is automated by `MemoryClassifier` (`src/cradare2/analysis/memory_classifier.cr`):

```crystal
# Classify an arbitrary pointer
classification = r2.debug.classify_memory(regs.rax)

puts "Address: 0x#{classification.address.to_s(16)}"
puts "Segment: #{classification.segment}"   # :stack, :heap, :code, :data, :unmapped
puts "Region:  #{classification.region_name}" # e.g. "game.dll" or "[heap]"
puts "Perms:   #{classification.permissions}" # e.g. "r-x"
puts "Valid:   #{classification.valid?}"
```

---

## 4. Root-Cause Crash Diagnosis (`diagnose_crash` & `crash_report`)

When a process faults, `cradare2` analyzes register values, memory maps, the faulting instruction opcode, and stack traces to infer the root cause.

### 4.1 Structured Diagnosis (`Model::CrashDiagnosis`)
```crystal
diagnosis = r2.debug.diagnose_crash

puts "Reason:         #{diagnosis.reason}"
puts "Probable Cause: #{diagnosis.probable_cause}"
# Potential Causes:
#   :null_dereference  - Dereferencing pointer near 0x0
#   :null_branch       - Jumping to null address (e.g. uninitialized vtable)
#   :wild_jump         - PC in unmapped memory
#   :stack_corruption  - SP outside valid stack boundary
#   :access_violation  - Writing to read-only or non-existent region

puts "\nRemediation Recommendations:"
diagnosis.recommendations.each do |rec|
  puts "  - #{rec}"
end
```

### 4.2 Comprehensive Formatted Crash Report (`crash_report`)
```crystal
puts r2.debug.crash_report
```

Output:
```text
=== Native Crash Diagnostic Report ===
Crash PC (Instruction Pointer): 0x140001032
Stack Pointer (SP):             0x7ffc20c3c500
Base/Frame Pointer (BP):        0x7ffc20c3c540

Active Function: MyGame::Player#_process:Float64
Faulting Region: game.dll (0x140000000 - 0x140050000, -r-x)

Registers:
  RAX: 0x0             RBX: 0x140020000     RCX: 0x7ffc20c3c500
  RDX: 0x140055000     RSI: 0x3e8           RDI: 0x7d0
  R8:  0x1             R9:  0x2             R10: 0x3

Call Stack (Demangled):
  #0 0x140001032 in MyGame::Player#_process:Float64
  #1 0x1400010a0 in MyGame::Player#update
  #2 0x140002100 in Godot::MainLoop#iteration
```

---

## 5. Crystal Runtime Object Inspection (`client.crystal`)

`cradare2` knows the internal binary memory layouts of standard Crystal data structures:

### 5.1 Crystal `String`
Layout:
- Offset `0`: `type_id` (UInt32)
- Offset `4`: `bytesize` (Int32)
- Offset `8`: `length` (Int32)
- Offset `12`: Raw UTF-8 bytes (null-terminated)

```crystal
string_obj = r2.crystal.read_string(0x140500000)
puts "Value:    #{string_obj.value}"
puts "Bytesize: #{string_obj.bytesize}"
puts "Length:   #{string_obj.length}"
```

### 5.2 Crystal `Array(T)`
Header layout:
- Offset `0`: `type_id` (UInt32)
- Offset `4`: `length` (Int32)
- Offset `8`: `capacity` (Int32)
- Offset `16`: `buffer_address` (Pointer)

```crystal
arr = r2.crystal.read_array_header(0x140600000)
puts "Array Size:     #{arr.size}"
puts "Array Capacity: #{arr.capacity}"
puts "Buffer Address: 0x#{arr.buffer_address.to_s(16)}"
```

### 5.3 Crystal `Slice(T)`
Slice layout:
- Offset `0`: `length` (Int32)
- Offset `4`: `read_only` (Bool / Int32)
- Offset `8`: `pointer` (Pointer)

```crystal
slice = r2.crystal.read_slice_header(0x140700000)
puts "Slice Size: #{slice.size} (Read-only: #{slice.read_only?})"
```

### 5.4 Crystal `Fiber`
Inspect running fibers in multithreaded runtimes:
```crystal
fiber = r2.crystal.read_fiber(0x140800000)
puts "Fiber Address: 0x#{fiber.address.to_s(16)}"
puts "Stack Pointer: 0x#{fiber.stack_address.to_s(16)}"
puts "Resume Context: 0x#{fiber.resume_context.to_s(16)}"
```
