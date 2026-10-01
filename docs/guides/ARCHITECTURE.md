# Cradare2 Architecture & Internals Guide

This document describes the internal architecture, design principles, and subsystem organization of `cradare2`.

---

## 1. System Overview

`cradare2` is an idiomatic Crystal framework for programmatic binary analysis, debugging, memory forensics, and reverse engineering powered by [radare2](https://www.radare.org/).

The architecture is organized into four distinct tiers:

```
┌─────────────────────────────────────────────────────────┐
│                    User Applications                    │
│   (CLI Tools, Game Engine Plugins, Debuggers, Shards)   │
└────────────────────────────┬────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────┐
│                    High-Level DSLs                      │
│   ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐   │
│   │   Analyze   │ │   Disasm    │ │     Memory      │   │
│   └─────────────┘ └─────────────┘ └─────────────────┘   │
│   ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐   │
│   │    Debug    │ │    Flags    │ │    Comments     │   │
│   └─────────────┘ └─────────────┘ └─────────────────┘   │
│   ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐   │
│   │    Types    │ │   Crystal   │ │  Lines/Source   │   │
│   └─────────────┘ └─────────────┘ └─────────────────┘   │
└────────────────────────────┬────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────┐
│                      Client Core                        │
│   - Unified Address Translation (UInt64 | String)       │
│   - Strongly-Typed JSON Deserialization (cmdj)          │
│   - Asynchronous Execution & Fiber Timeouts             │
│   - Command Dispatcher & Plugin Pipe Server             │
│   - Profiling Hooks & Batch Execution                   │
└────────────────────────────┬────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────┐
│                   Transport Layer                       │
│   ┌───────────────────┐       ┌─────────────────────┐   │
│   │  ProcessTransport │       │    HttpTransport    │   │
│   │ (Subprocess r2)   │       │  (REST / Webserver) │   │
│   └───────────────────┘       └─────────────────────┘   │
│   ┌───────────────────┐       ┌─────────────────────┐   │
│   │  InSessionTransport       │    MockTransport    │   │
│   │  (#!pipe Server)  │       │  (Zero-Dep Testing) │   │
│   └───────────────────┘       └─────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Transport Layer (`Cradare2::Transport`)

All communication between Crystal and radare2 flows through the `Transport` interface (`src/cradare2/transport/base.cr`):

```crystal
module Cradare2
  module Transport
    abstract class Base
      abstract def send(cmd : String) : String
      abstract def close : Nil
      abstract def open? : Bool
    end
  end
end
```

### 2.1 Subprocess Transport (`ProcessTransport`)
- **Invocation**: Launches `radare2 -q0 <target>` (or `-q0 -d <target>` for debugging).
- **Framing**: Radare2's `-q0` mode delimits every command response with a trailing null byte (`\0`). The transport continuously reads from the subprocess STDOUT until `\0` is encountered.
- **Asynchronous Timeout & Fiber Safety**: Command timeouts are enforced asynchronously via dedicated timer fibers and Channels (`Channel(String | Exception)`). If radare2 hangs or deadlocks, the waiting fiber unblocks, terminates the child process, captures STDERR diagnostics, and raises `Cradare2::TimeoutError`.

### 2.2 In-Session Transport (`InSessionTransport`)
- **Invocation**: When a Crystal script is executed directly inside an active radare2 session via `#!pipe <command>` or `r2 -i <script>`.
- **Environment Detection**: Detects radare2 pipe file descriptors through environment variables:
  1. `R2PIPE_IN` and `R2PIPE_OUT` (file descriptor numbers).
  2. `R2PIPE_PATH` (named pipe on Windows or Unix domain socket).
- **EOF Resilience**: If the parent radare2 session terminates or closes the pipe, `InSessionTransport` detects EOF immediately and raises `Cradare2::ProcessTerminatedError`.

### 2.3 Deterministic Mock Transport (`MockTransport`)
- Pure Crystal in-memory transport for deterministic unit and integration tests.
- Allows test suites to define command handlers without needing a running radare2 installation or file system side effects:
  ```crystal
  client = Cradare2.mock do |cmd|
    case cmd
    when "ij" then %({"bin":{"arch":"x86","bits":64,"os":"windows"}})
    else ""
    end
  end
  ```

---

## 3. Client Core (`Cradare2::Client`)

The `Client` encapsulates state, command routing, and error classification.

### 3.1 Unified Address Representation (`Address`)
Radare2 commands accept hex offsets (`0x401000`), decimal offsets (`4198400`), CPU registers (`rip`, `rsp`), and flag names (`sym.main`).

To eliminate manual string formatting and conversions, `cradare2` provides the `Address` type union:
```crystal
alias Address = UInt64 | Int64 | Int32 | String
```

`AddressUtils.to_u64?(address)` and `AddressUtils.to_hex(address)` seamlessly resolve:
- Integers to standard hexadecimal strings (`0x140001007`).
- Hexadecimal strings (`"0x401000"`, `"401000h"`).
- Decimal string offsets returned by radare2 seek commands (`"4198400"`).
- Symbol and register strings passed directly without alteration.

### 3.2 Command Pipelining and Deserialization
- `client.cmd(string)`: Sends raw radare2 command and returns the raw output string.
- `client.cmdj(string)`: Dynamic JSON query returning `JSON::Any`.
- `client.cmdj(string, as: ModelClass)`: Strongly-typed JSON deserialization into any `JSON::Serializable` model.
- `client.safe_cmdj(string, as: ModelClass)`: Resilient query returning `nil` instead of raising an exception if radare2 outputs empty text or malformed JSON.
- `client.batch(commands)`: Batches multiple commands separated by newlines or semicolons in a single pipe write for high throughput.

### 3.3 Command Profiling & Hooking
Applications can monitor command traffic, track execution latency, and log slow queries via `client.on_command`:
```crystal
client.on_command do |cmd, elapsed|
  if elapsed > 100.milliseconds
    Log.warn { "Slow r2 command: #{cmd} took #{elapsed.total_milliseconds}ms" }
  end
end
```

---

## 4. Error Hierarchy

All exceptions in `cradare2` inherit from `Cradare2::Error`:

```
Cradare2::Error
├── Cradare2::BinaryNotFoundError
├── Cradare2::CommandError
├── Cradare2::ParseError
├── Cradare2::SessionClosedError
├── Cradare2::TimeoutError
├── Cradare2::TransportError
├── Cradare2::ProcessTerminatedError
├── Cradare2::SymbolResolutionError
├── Cradare2::MemoryInspectionError
└── Cradare2::TypeDefinitionError
```

- **`ProcessTerminatedError`**: Raised when the debuggee or radare2 subprocess crashes or closes unexpectedly.
- **`SymbolResolutionError`**: Raised when attempting to resolve an invalid or non-existent symbol.
- **`MemoryInspectionError`**: Raised when reading invalid or unmapped memory regions.
- **`TypeDefinitionError`**: Raised when defining malformed `pf` print formats or mismatched struct fields.

---

## 5. Domain-Specific Languages (DSLs)

DSLs provide expressive, fluent APIs over radare2's cryptic letter commands:

| DSL | Radare2 Base | Description |
|---|---|---|
| `client.analyze` | `a...` | Binary analysis (`all`, `calls`, `functions`, `preludes`, `emulate`) |
| `client.disasm` | `p...` | Disassembly, opcode inspection, Ghidra decompilation (`pdc`/`pdg`) |
| `client.memory` | `m...`, `w...`, `p...` | Memory reading/writing, hexdump, C-strings, pointer arrays |
| `client.debug` | `d...` | Process control, registers, breakpoints, memory maps, module forensics |
| `client.flags` | `f...`, `fs...` | Flag creation, queries, batch injection, and Flag Spaces |
| `client.comments` | `CC...` | Safe Base64-encoded comment injection and querying |
| `client.types` | `pf...` | C/C++ struct format registration and structured JSON decoding |
| `client.crystal` | — | Crystal runtime inspection (`String`, `Array`, `Slice`, `Fiber`, `Hash`) |
| `client.lines` | `CL...` | Source line to assembly instruction matching and synchronization |

---

## 6. Thread-Safe Demangler Architecture

`Cradare2::Util::Demangler` translates mangled C++, Rust, and Crystal compiler symbols into human-readable signatures.

### 6.1 Multi-Format Demangling
1. **Crystal Mangling**:
   - `*Namespace::Class#method:Type`
   - Operator normalization: `+`, `-`, `*`, `/`, `[]`, `[]=`, `<<`, `>>`, `<=>`, `===`, `&+=`, `&*`, etc.
2. **LLVM / MSVC PDB Escapes**:
   - Decodes hex escape sequences produced by LLVM and MSVC tools (`_2A.`, `.3A.`, `.23.`, `.3C.`, `.3E.`, `.28.`, `.29.`, `.2C.`, `.20.`, `.7C.`, `.5B.`, `.5D.`, `.3D.`, etc.).
3. **Prefix Sanitization**:
   - Strips radare2 internal prefixes (`pdb.`, `sym.pdb.`, `sym.`, `sym.imp.`, `reloc.`).

### 6.2 Bounded Cache & Mutex Synchronization
- Demangling is frequently executed inside loops displaying thousands of instructions or stack frames.
- A thread-safe cache backed by `Thread::Mutex` avoids redundant regex execution.
- Bounded to `50_000` entries to prevent unbounded memory growth during long-running sessions.
