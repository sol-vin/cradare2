require "./models/function"
require "./models/symbol"
require "./models/stack_frame"
require "./util/demangler"
require "./lines/line_helper"
require "./address"

module Cradare2
  # Crystal-specific binary analysis, memory layout inspection, and debugging tools.
  class CrystalHelper
    getter client : Client

    # Struct representing a Crystal `String` in target process memory.
    #
    # Memory Layout (64-bit Crystal):
    # - Offset 0: `type_id : Int32` (4 bytes)
    # - Offset 4: `bytesize : Int32` (4 bytes)
    # - Offset 8: `length : Int32` (4 bytes)
    # - Offset 12: UTF-8 payload bytes followed by null terminator
    struct CrystalString
      getter address : UInt64
      getter type_id : Int32
      getter bytesize : Int32
      getter length : Int32
      getter value : String

      def initialize(
        @address : UInt64,
        @type_id : Int32,
        @bytesize : Int32,
        @length : Int32,
        @value : String,
      )
      end
    end

    # Struct representing a Crystal `Array(T)` reference header in target memory (64-bit).
    #
    # Memory Layout:
    # - Offset 0: `type_id : Int32` (4 bytes)
    # - Offset 4: `size : Int32` (4 bytes)
    # - Offset 8: `capacity : Int32` (4 bytes)
    # - Offset 12..15: 4 bytes alignment padding
    # - Offset 16: `buffer : Pointer(T)` (8 bytes UInt64)
    struct CrystalArrayHeader
      getter address : UInt64
      getter type_id : Int32
      getter size : Int32
      getter capacity : Int32
      getter buffer_address : UInt64

      def initialize(
        @address : UInt64,
        @type_id : Int32,
        @size : Int32,
        @capacity : Int32,
        @buffer_address : UInt64,
      )
      end
    end

    # Struct representing a Crystal `Slice(T)` value struct in target memory (64-bit).
    #
    # Memory Layout:
    # - Offset 0: `size : Int32` (4 bytes)
    # - Offset 4: `read_only : Bool` (1 byte UInt8 + 3 bytes padding)
    # - Offset 8: `pointer : Pointer(T)` (8 bytes UInt64)
    struct CrystalSliceHeader
      getter address : UInt64
      getter size : Int32
      getter read_only : Bool
      getter pointer_address : UInt64

      def initialize(
        @address : UInt64,
        @size : Int32,
        @read_only : Bool,
        @pointer_address : UInt64,
      )
      end
    end

    # Struct representing a Crystal `Fiber` reference in target memory (64-bit).
    struct CrystalFiber
      getter address : UInt64
      getter type_id : Int32
      getter stack_address : UInt64
      getter stack_size : Int32
      getter resumable : Bool

      def initialize(
        @address : UInt64,
        @type_id : Int32,
        @stack_address : UInt64,
        @stack_size : Int32,
        @resumable : Bool,
      )
      end
    end

    # Struct representing a Crystal `Hash(K, V)` header in target memory (64-bit).
    struct CrystalHashHeader
      getter address : UInt64
      getter type_id : Int32
      getter size : Int32
      getter capacity : Int32

      def initialize(
        @address : UInt64,
        @type_id : Int32,
        @size : Int32,
        @capacity : Int32,
      )
      end
    end

    # Struct representing parsed information from a Crystal symbol.
    struct CrystalSymbolInfo
      getter raw : String
      getter cleaned : String
      getter class_name : String?
      getter method_name : String?
      getter is_instance_method : Bool

      def initialize(
        @raw : String,
        @cleaned : String,
        @class_name : String?,
        @method_name : String?,
        @is_instance_method : Bool,
      )
      end
    end

    @lines : Lines::LineHelper?

    def initialize(@client : Client)
    end

    # Accessor for source-line-to-assembly instruction matching tools.
    def lines : Lines::LineHelper
      @lines ||= Lines::LineHelper.new(@client)
    end

    # Block form for `lines` DSL.
    def lines(&block : Lines::LineHelper -> U) : U forall U
      yield lines
    end

    # Returns true if the binary appears to be compiled with Crystal.
    # Checks for the presence of `__crystal_main`, `*Crystal::*`, Boehm GC symbols, or Crystal mangling.
    def crystal_binary? : Bool
      symbols = @client.symbols
      functions = @client.functions

      symbols.any? do |s|
        Util::Demangler.is_crystal_symbol?(s.name) ||
          s.name.includes?("__crystal_main") ||
          s.name.includes?("Crystal::") ||
          s.name.includes?("GC_init") ||
          s.name.includes?("GC_malloc")
      end || functions.any? do |f|
        Util::Demangler.is_crystal_symbol?(f.name) ||
          f.name.includes?("__crystal_main") ||
          f.name.includes?("Crystal::") ||
          f.name.includes?("GC_init")
      end
    end

    # Returns the address of `__crystal_main` or entry function if found.
    def entrypoint : UInt64?
      fn = crystal_main_function
      return fn.offset if fn

      sym = @client.symbols.find { |s| s.name.includes?("__crystal_main") }
      sym ? sym.vaddr : nil
    end

    # Returns the `__crystal_main` function model if analyzed.
    def crystal_main_function : Model::Function?
      @client.functions.find do |f|
        f.name.includes?("__crystal_main") || f.name.ends_with?("~crystal_main")
      end
    end

    # Returns all Boehm GC related functions found in the binary.
    def gc_functions : Array(Model::Function)
      @client.functions.select do |f|
        f.name.includes?("GC_")
      end
    end

    # Returns all Boehm GC related symbols found in the binary.
    def gc_symbols : Array(Model::Symbol)
      @client.symbols.select do |s|
        s.name.includes?("GC_")
      end
    end

    # Discovers all distinct Crystal class, struct, and module names present in the binary.
    def classes : Array(String)
      class_set = Set(String).new

      @client.functions.each do |f|
        info = parse_symbol(f.name)
        if c = info.class_name
          class_set << c unless c.empty?
        end
      end

      @client.symbols.each do |s|
        info = parse_symbol(s.name)
        if c = info.class_name
          class_set << c unless c.empty?
        end
      end

      class_set.to_a.sort
    end

    # Finds all analyzed functions belonging to a given Crystal class name.
    def methods_for_class(class_name : String) : Array(Model::Function)
      @client.functions.select do |f|
        info = parse_symbol(f.name)
        info.class_name == class_name
      end
    end

    # Finds all symbols belonging to a given Crystal class name.
    def symbols_for_class(class_name : String) : Array(Model::Symbol)
      @client.symbols.select do |s|
        info = parse_symbol(s.name)
        info.class_name == class_name
      end
    end

    # Parses a Crystal symbol into its constituent class and method parts.
    def parse_symbol(symbol : String) : CrystalSymbolInfo
      cleaned = Util::Demangler.clean_crystal_symbol(symbol)
      parsed = Util::Demangler.parse_crystal_method(cleaned)

      if parsed
        class_name, method_name, is_instance = parsed
        CrystalSymbolInfo.new(symbol, cleaned, class_name, method_name, is_instance)
      else
        CrystalSymbolInfo.new(symbol, cleaned, nil, nil, false)
      end
    end

    # Reads the 4-byte `type_id` of a Crystal reference object at `address`.
    def read_type_id(address : Address) : Int32
      addr_u64 = AddressUtils.to_u64(address)
      @client.memory.read_i32(addr_u64)
    end

    # Inspects and reads a Crystal `String` from memory at `address`.
    def read_string(address : Address, max_bytes : Int32 = 1048576) : CrystalString
      addr_u64 = AddressUtils.to_u64(address)
      type_id = @client.memory.read_i32(addr_u64)
      bytesize = @client.memory.read_i32(addr_u64 + 4)
      length = @client.memory.read_i32(addr_u64 + 8)

      # Bound bytesize to avoid massive allocations on corrupted/unmapped memory
      safe_bytes = if bytesize < 0
                     0
                   elsif bytesize > max_bytes
                     max_bytes
                   else
                     bytesize
                   end

      val_bytes = if safe_bytes > 0
                    @client.memory.read_bytes(addr_u64 + 12, safe_bytes)
                  else
                    Bytes.empty
                  end

      CrystalString.new(
        address: addr_u64,
        type_id: type_id,
        bytesize: bytesize,
        length: length,
        value: String.new(val_bytes)
      )
    end

    # Convenience method to read just the UTF-8 String value of a Crystal `String` at `address`.
    def read_string_value(address : Address, max_bytes : Int32 = 1048576) : String
      read_string(address, max_bytes).value
    end

    # Inspects and reads a Crystal `Array(T)` header from memory at `address`.
    def read_array_header(address : Address) : CrystalArrayHeader
      addr_u64 = AddressUtils.to_u64(address)
      type_id = @client.memory.read_i32(addr_u64)
      size = @client.memory.read_i32(addr_u64 + 4)
      capacity = @client.memory.read_i32(addr_u64 + 8)
      buf_addr = @client.memory.read_u64(addr_u64 + 16)

      CrystalArrayHeader.new(
        address: addr_u64,
        type_id: type_id,
        size: size,
        capacity: capacity,
        buffer_address: buf_addr
      )
    end

    # Inspects and reads a Crystal `Slice(T)` struct header from memory at `address`.
    def read_slice_header(address : Address) : CrystalSliceHeader
      addr_u64 = AddressUtils.to_u64(address)
      size = @client.memory.read_i32(addr_u64)
      ro_byte = @client.memory.read_u8(addr_u64 + 4)
      ptr = @client.memory.read_u64(addr_u64 + 8)

      CrystalSliceHeader.new(
        address: addr_u64,
        size: size,
        read_only: ro_byte != 0,
        pointer_address: ptr
      )
    end

    # Inspects and reads a Crystal `Fiber` struct from memory at `address`.
    def read_fiber(address : Address) : CrystalFiber
      addr_u64 = AddressUtils.to_u64(address)
      type_id = @client.memory.read_i32(addr_u64)
      resumable = @client.memory.read_u8(addr_u64 + 4) != 0
      stack_size = @client.memory.read_i32(addr_u64 + 8)
      stack_addr = @client.memory.read_u64(addr_u64 + 16)

      CrystalFiber.new(
        address: addr_u64,
        type_id: type_id,
        stack_address: stack_addr,
        stack_size: stack_size,
        resumable: resumable
      )
    end

    # Inspects and reads a Crystal `Hash(K, V)` header from memory at `address`.
    def read_hash_header(address : Address) : CrystalHashHeader
      addr_u64 = AddressUtils.to_u64(address)
      type_id = @client.memory.read_i32(addr_u64)
      size = @client.memory.read_i32(addr_u64 + 4)
      capacity = @client.memory.read_i32(addr_u64 + 8)

      CrystalHashHeader.new(
        address: addr_u64,
        type_id: type_id,
        size: size,
        capacity: capacity
      )
    end

    # Returns the current call stack with demangled Crystal function and class names.
    def demangled_backtrace : Array(Model::StackFrame)
      frames = @client.debug.backtrace
      frames.map do |frame|
        demangled_name = if fn = frame.function_name
                           Util::Demangler.demangle(fn, @client.transport)
                         else
                           nil
                         end
        Model::StackFrame.new(
          frame: frame.frame,
          raw_pc: frame.pc,
          raw_function: demangled_name || frame.function,
          sp: frame.sp,
          bp: frame.bp
        )
      end
    end

    # Generates a detailed crash report with demangled Crystal stack traces, registers,
    # and binary context.
    def crash_report : String
      String.build do |str|
        str.puts "# Crystal Target Crash / Debug Report"
        str.puts "Generated at: #{Time.utc}"
        str.puts

        info = @client.info
        if bin = info.bin
          str.puts "## Binary Information"
          str.puts "- Architecture: #{bin.arch} (#{bin.bits}-bit, #{bin.endian} endian)"
          str.puts "- OS / Format: #{bin.os} / #{bin.bintype}"
          if core = info.core
            str.puts "- Path: #{core.file}"
          end
          str.puts
        end

        regs = @client.debug.registers
        str.puts "## Registers"
        str.puts "- RIP / PC : 0x#{regs.pc.to_s(16)}"
        str.puts "- RSP / SP : 0x#{regs.sp.to_s(16)}"
        str.puts "- RAX      : 0x#{regs.rax.to_s(16)}" if regs.values["rax"]?
        str.puts "- RBX      : 0x#{regs.rbx.to_s(16)}" if regs.values["rbx"]?
        str.puts "- RCX      : 0x#{regs.rcx.to_s(16)}" if regs.values["rcx"]?
        str.puts "- RDX      : 0x#{regs.rdx.to_s(16)}" if regs.values["rdx"]?
        str.puts

        str.puts "## Current Instruction"
        pc = regs.pc
        if pc > 0
          insts = @client.disasm.at(pc, 1)
          if current_inst = insts.first?
            str.puts "```asm"
            str.puts "0x#{current_inst.offset.to_s(16)}: #{current_inst.opcode}"
            str.puts "```"
          end
        end
        str.puts

        str.puts "## Demangled Backtrace"
        bt = demangled_backtrace
        if bt.empty?
          str.puts "No stack frames available."
        else
          bt.each do |frame|
            fn_desc = frame.function_name || "unknown"
            str.puts "- [#{frame.frame}] 0x#{frame.address.to_s(16)} in `#{fn_desc}`"
          end
        end
      end
    end

    # Demangles a single symbol using the multi-language demangler.
    def demangle_symbol(symbol : String) : String
      Util::Demangler.demangle(symbol, @client.transport)
    end

    # Discovers all mangled Crystal symbols and functions, demangles them,
    # and optionally applies the demangled names directly into the radare2 session
    # via `afn` (analyze function name) and `fr` (flag rename).
    def demangle_all(apply_to_r2 : Bool = false) : Hash(UInt64, String)
      results = Hash(UInt64, String).new

      @client.functions.each do |fn|
        demangled = Util::Demangler.demangle(fn.name, @client.transport)
        if demangled != fn.name
          results[fn.offset] = demangled
          if apply_to_r2
            # Clean for radare2 name compatibility (replace spaces/quotes)
            safe_name = demangled.gsub(' ', '_').gsub('"', "").gsub('\'', "")
            @client.cmd("afn \"#{safe_name}\" 0x#{fn.offset.to_s(16)}")
          end
        end
      end

      @client.symbols.each do |sym|
        demangled = Util::Demangler.demangle(sym.name, @client.transport)
        if demangled != sym.name
          results[sym.vaddr] = demangled
          if apply_to_r2 && sym.vaddr > 0
            safe_name = demangled.gsub(' ', '_').gsub('"', "").gsub('\'', "")
            @client.cmd("fr \"#{sym.name}\" \"#{safe_name}\"")
          end
        end
      end

      results
    end
  end
end
