require "../models/symbol"
require "../models/memory_map"
require "../models/stack_frame"
require "../models/register"
require "../util/demangler"

module Cradare2
  module DSL
    # Diagnostic result for Godot 4 GDExtension verification.
    struct GDExtensionCheck
      getter valid : Bool
      getter entrypoint_found : Bool
      getter entrypoint_name : String?
      getter exports_count : Int32
      getter arch : String
      getter bits : Int32
      getter warnings : Array(String)

      def initialize(
        @valid : Bool,
        @entrypoint_found : Bool,
        @entrypoint_name : String?,
        @exports_count : Int32,
        @arch : String,
        @bits : Int32,
        @warnings : Array(String) = [] of String
      )
      end
    end

    # Specialized helper for inspecting and debugging Godot 4 GDExtensions and Crystal binaries.
    class LapisHelper
      # Common GDExtension entrypoint function names
      COMMON_ENTRYPOINTS = [
        "lapis_gdextension_entry",
        "godot_gdextension_entry",
        "gdextension_initialize",
        "gdextension_entry"
      ]

      def initialize(@client : Client)
      end

      # Verifies whether a binary or DLL properly exposes GDExtension entrypoints.
      def verify_gdextension : GDExtensionCheck
        exports = @client.exports
        info = @client.info
        warnings = [] of String

        entry_name : String? = nil
        found_entry = false

        exports.each do |exp|
          clean_name = exp.name.lstrip('_')
          if COMMON_ENTRYPOINTS.any? { |ep| clean_name.includes?(ep) }
            found_entry = true
            entry_name = exp.name
            break
          end
        end

        if !found_entry
          warnings << "No standard GDExtension entrypoint found (expected one of: #{COMMON_ENTRYPOINTS.join(", ")})"
        end

        if exports.empty?
          warnings << "Binary exports table is empty; Godot will not be able to locate entrypoints"
        end

        valid = found_entry && warnings.empty?

        GDExtensionCheck.new(
          valid: valid,
          entrypoint_found: found_entry,
          entrypoint_name: entry_name,
          exports_count: exports.size,
          arch: info.arch,
          bits: info.bits,
          warnings: warnings
        )
      end

      # Discovers and demangles all Crystal symbols in the binary.
      def find_crystal_symbols : Array(Model::Symbol)
        symbols = @client.symbols
        results = [] of Model::Symbol

        symbols.each do |sym|
          if Util::Demangler.is_crystal_symbol?(sym.name) ||
             (sym.demangled && Util::Demangler.is_crystal_symbol?(sym.demangled.not_nil!))
            results << sym
          end
        end

        results
      end

      # Discovers all Godot GDExtension / API imports or calls.
      def find_godot_bindings : Array(Model::Import)
        imports = @client.imports
        imports.select do |imp|
          name = imp.name.downcase
          name.includes?("godot") || name.includes?("gdextension")
        end
      end

      # Checks for Crystal GC symbols (Boehm GC).
      def find_gc_symbols : Array(Model::Symbol)
        @client.symbols.select do |sym|
          sym.name.includes?("GC_") || sym.name.includes?("gc_")
        end
      end

      # Analyzes current crash state from the debugger and generates a diagnostic report.
      def inspect_crash(
        regs : Model::Registers? = nil,
        bt : Array(Model::StackFrame)? = nil
      ) : String
        registers = regs || @client.debug.registers
        backtrace = bt || @client.debug.backtrace
        pc = registers.pc

        io = IO::Memory.new
        io.puts "=== Lapis / GDExtension Crash Diagnostic ==="
        io.puts "Crash PC (Instruction Pointer): 0x#{pc.to_s(16)}"
        io.puts "Stack Pointer: 0x#{registers.sp.to_s(16)}"
        io.puts "Base Pointer:  0x#{registers.bp.to_s(16)}"
        io.puts

        # Identify nearest symbol or function
        fn_name = "unknown"
        begin
          res = @client.cmd("fd @ 0x#{pc.to_s(16)}").strip
          fn_name = res unless res.empty?
        rescue
        end
        io.puts "Active Function: #{Util::Demangler.demangle(fn_name, @client.transport)}"

        # Identify memory map
        maps = @client.debug.maps
        matching_map = maps.find { |m| m.contains?(pc) }
        if matching_map
          io.puts "Faulting Region: #{matching_map.name} (0x#{matching_map.addr.to_s(16)} - 0x#{matching_map.addr_end.to_s(16)}, #{matching_map.perm})"
        else
          io.puts "Faulting Region: UNMAPPED MEMORY (Possible Null Pointer or Wild Branch!)"
        end

        # Registers dump
        io.puts "\nRegisters:"
        if @client.info.bits == 64
          io.puts "  RAX: 0x#{registers.rax.to_s(16)}  RBX: 0x#{registers.rbx.to_s(16)}  RCX: 0x#{registers.rcx.to_s(16)}"
          io.puts "  RDX: 0x#{registers.rdx.to_s(16)}  RSI: 0x#{registers.rsi.to_s(16)}  RDI: 0x#{registers.rdi.to_s(16)}"
          io.puts "  R8:  0x#{registers.r8.to_s(16)}   R9:  0x#{registers.r9.to_s(16)}   R10: 0x#{registers.r10.to_s(16)}"
        else
          io.puts "  EAX: 0x#{registers.eax.to_s(16)}  EBX: 0x#{registers.ebx.to_s(16)}  ECX: 0x#{registers.ecx.to_s(16)}"
          io.puts "  EDX: 0x#{registers.edx.to_s(16)}  ESI: 0x#{registers.esi.to_s(16)}  EDI: 0x#{registers.edi.to_s(16)}"
        end

        # Backtrace
        io.puts "\nDemangled Backtrace:"
        if backtrace.empty?
          io.puts "  (No stack frames captured)"
        else
          backtrace.each_with_index do |frame, idx|
            demangled = Util::Demangler.demangle(frame.function, @client.transport)
            io.puts "  ##{idx} 0x#{frame.pc.to_s(16)} in #{demangled}"
          end
        end

        io.to_s
      end
    end
  end
end
