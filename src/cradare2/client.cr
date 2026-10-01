require "json"
require "./error"
require "./address"
require "./transport/transport"
require "./models/binary_info"
require "./models/function"
require "./models/basic_block"
require "./models/symbol"
require "./models/section"
require "./models/string_item"
require "./models/instruction"
require "./models/register"
require "./models/breakpoint"
require "./models/stack_frame"
require "./models/memory_map"
require "./models/module_info"
require "./models/flag"
require "./models/thread"
require "./util/demangler"
require "./models/xref"
require "./models/security_info"
require "./analysis/memory_classifier"
require "./models/crash_diagnosis"
require "./dsl/analysis"
require "./dsl/disasm"
require "./dsl/memory"
require "./dsl/debugger"
require "./dsl/flags"
require "./dsl/comments"
require "./dsl/types"
require "./crystal"

module Cradare2
  # The central client representing an open radare2 session.
  class Client
    getter transport : Transport::Base

    @analysis : DSL::Analysis?
    @disasm : DSL::Disassembly?
    @memory : DSL::Memory?
    @debugger : DSL::Debugger?
    @crystal : CrystalHelper?
    @flags : DSL::Flags?
    @comments : DSL::Comments?
    @types : DSL::Types?
    @command_listeners = [] of Proc(String, Time::Span, Bool, Nil)

    def initialize(@transport : Transport::Base)
    end

    # Registers a diagnostic listener block invoked after every command execution with (command, duration, success).
    def on_command(&block : String, Time::Span, Bool -> Nil) : Nil
      @command_listeners << block
    end

    # Clears all registered command listeners.
    def clear_command_hooks : self
      @command_listeners.clear
      self
    end

    # Executes a command string in radare2 and returns the raw output string.
    def cmd(command : String) : String
      start = Time.instant
      begin
        output = @transport.cmd(command)
        duration = Time.instant - start
        notify_command(command, duration, true)
        output
      rescue ex
        duration = Time.instant - start
        notify_command(command, duration, false)
        raise ex
      end
    end

    # Executes a batch of commands sequentially, returning a mapping of Command => Output.
    def batch(commands : Array(String)) : Hash(String, String)
      results = Hash(String, String).new
      commands.each do |c|
        clean = c.strip
        next if clean.empty?
        results[clean] = cmd(clean)
      end
      results
    end

    # Executes a command and parses the returned JSON string as `JSON::Any`.
    def cmdj(command : String) : JSON::Any
      output = cmd(command).strip
      return JSON::Any.new(nil) if output.empty?
      JSON.parse(output)
    rescue ex : JSON::ParseException
      raise ParseError.new("Failed to parse JSON response for command '#{command}': #{ex.message}\nOutput: #{output}", cause: ex)
    end

    # Executes a command and deserializes the JSON string into the specified type `T`.
    def cmdj(command : String, as type : T.class) : T forall T
      output = cmd(command).strip
      if output.empty?
        raise ParseError.new("Empty response received for command '#{command}', expected JSON of type #{T}")
      end
      T.from_json(output)
    rescue ex : JSON::ParseException | TypeCastError
      raise ParseError.new("Failed to deserialize JSON for command '#{command}' into #{T}: #{ex.message}\nOutput: #{output}", cause: ex)
    end

    # Safely parses JSON response into specified model type T, returning nil on parse error or empty output.
    def safe_cmdj(command : String, as type : T.class) : T? forall T
      output = cmd(command).strip
      return nil if output.empty? || output == "null"
      type.from_json(output)
    rescue ex : JSON::ParseException | TypeCastError
      nil
    end

    # Safely parses dynamic JSON response returning JSON::Any, or nil on parse error or empty output.
    def safe_cmdj(command : String) : JSON::Any?
      output = cmd(command).strip
      return nil if output.empty? || output == "null"
      JSON.parse(output)
    rescue ex : JSON::ParseException
      nil
    end

    # Helper that catches JSON parse errors on empty/unparsed data, returning default value.
    def safe_cmdj(command : String, as type : T.class, default : T) : T forall T
      safe_cmdj(command, as: type) || default
    end

    # Seeks to the specified target address or symbol (s <target>).
    def seek(target : Address) : self
      target_str = AddressUtils.to_hex(target)
      cmd("s #{target_str}")
      self
    end

    # Returns the current seek position / offset.
    def current_offset : UInt64
      res = cmd("s").strip
      AddressUtils.to_u64?(res) || 0_u64
    end

    # Returns binary metadata (ij).
    def info : Model::BinaryInfo
      safe_cmdj("ij", as: Model::BinaryInfo, default: Model::BinaryInfo.new)
    end

    # Returns analyzed functions (aflj).
    def functions : Array(Model::Function)
      safe_cmdj("aflj", as: Array(Model::Function), default: [] of Model::Function)
    end

    # Returns all symbols in the binary (isj).
    def symbols : Array(Model::Symbol)
      safe_cmdj("isj", as: Array(Model::Symbol), default: [] of Model::Symbol)
    end

    # Returns exported symbols (iEj).
    def exports : Array(Model::Export)
      safe_cmdj("iEj", as: Array(Model::Export), default: [] of Model::Export)
    end

    # Returns imported symbols (iij).
    def imports : Array(Model::Import)
      safe_cmdj("iij", as: Array(Model::Import), default: [] of Model::Import)
    end

    # Returns binary sections (iSj).
    def sections : Array(Model::Section)
      safe_cmdj("iSj", as: Array(Model::Section), default: [] of Model::Section)
    end

    # Returns strings in data sections (izj).
    def strings : Array(Model::StringItem)
      safe_cmdj("izj", as: Array(Model::StringItem), default: [] of Model::StringItem)
    end

    # Returns strings from the entire binary (izzj).
    def all_strings : Array(Model::StringItem)
      safe_cmdj("izzj", as: Array(Model::StringItem), default: [] of Model::StringItem)
    end

    # Demangles a symbol using radare2 and internal caching.
    def demangle(symbol : String) : String
      Util::Demangler.demangle(symbol, @transport)
    end

    # Returns cross-references targeting the specified address or symbol (axtj @ <addr>).
    def xrefs_to(address : Address) : Array(Model::Xref)
      addr_str = AddressUtils.to_hex(address)
      safe_cmdj("axtj @ #{addr_str}", as: Array(Model::Xref), default: [] of Model::Xref)
    end

    # Returns cross-references originating from the specified address or symbol (axfj @ <addr>).
    def xrefs_from(address : Address) : Array(Model::Xref)
      addr_str = AddressUtils.to_hex(address)
      safe_cmdj("axfj @ #{addr_str}", as: Array(Model::Xref), default: [] of Model::Xref)
    end

    # Evaluates binary security mitigations (ASLR, DEP/NX, Stack Canary, Relocations).
    def security : Model::SecurityInfo
      Model::SecurityInfo.from_bin_info(info.bin)
    end

    # Finds a specific symbol by name or display name.
    def find_symbol(name : String) : Model::Symbol?
      symbols.find { |s| s.name == name || s.display_name == name }
    end

    # Finds a specific function by name.
    def find_function(name : String) : Model::Function?
      functions.find { |f| f.name == name }
    end

    # Filters symbols matching a substring or regex pattern.
    def symbols_matching(pattern : Regex | String) : Array(Model::Symbol)
      symbols.select do |s|
        case pattern
        when Regex
          pattern.matches?(s.name) || (s.demangled ? pattern.matches?(s.demangled.not_nil!) : false)
        when String
          s.name.includes?(pattern) || (s.demangled ? s.demangled.not_nil!.includes?(pattern) : false)
        else
          false
        end
      end
    end

    # Filters functions matching a substring or regex pattern.
    def functions_matching(pattern : Regex | String) : Array(Model::Function)
      functions.select do |f|
        case pattern
        when Regex
          pattern.matches?(f.name)
        when String
          f.name.includes?(pattern)
        else
          false
        end
      end
    end

    # Filters exports matching a substring or regex pattern.
    def exports_matching(pattern : Regex | String) : Array(Model::Export)
      exports.select do |e|
        case pattern
        when Regex
          pattern.matches?(e.name) || (e.demangled ? pattern.matches?(e.demangled.not_nil!) : false)
        when String
          e.name.includes?(pattern) || (e.demangled ? e.demangled.not_nil!.includes?(pattern) : false)
        else
          false
        end
      end
    end

    # Filters imports matching a substring or regex pattern.
    def imports_matching(pattern : Regex | String) : Array(Model::Import)
      imports.select do |i|
        case pattern
        when Regex
          pattern.matches?(i.name)
        when String
          i.name.includes?(pattern)
        else
          false
        end
      end
    end

    # Filters strings matching a substring.
    def strings_matching(query : String) : Array(Model::StringItem)
      strings.select { |s| s.string.includes?(query) }
    end

    # Access the Analysis DSL. Supports fluent chaining or block syntax.
    def analyze : DSL::Analysis
      @analysis ||= DSL::Analysis.new(self)
    end

    def analyze(&block : DSL::Analysis ->) : self
      block.call(analyze)
      self
    end

    # Access the Disassembly DSL.
    def disasm : DSL::Disassembly
      @disasm ||= DSL::Disassembly.new(self)
    end

    # Access the Memory DSL.
    def memory : DSL::Memory
      @memory ||= DSL::Memory.new(self)
    end

    def memory(&block : DSL::Memory ->) : self
      block.call(memory)
      self
    end

    # Access the Debugger DSL. Supports fluent chaining or block syntax.
    def debug : DSL::Debugger
      @debugger ||= DSL::Debugger.new(self)
    end

    def debug(&block : DSL::Debugger ->) : self
      block.call(debug)
      self
    end

    # Access the Flags DSL for managing symbols, labels, and markers.
    def flags : DSL::Flags
      @flags ||= DSL::Flags.new(self)
    end

    def flags(&block : DSL::Flags ->) : self
      block.call(flags)
      self
    end

    # Access the Comments DSL for managing code comments safely with Base64 encoding.
    def comments : DSL::Comments
      @comments ||= DSL::Comments.new(self)
    end

    def comments(&block : DSL::Comments ->) : self
      block.call(comments)
      self
    end

    # Access the Types DSL for defining and decoding binary structures via radare2 pf and pfj.
    def types : DSL::Types
      @types ||= DSL::Types.new(self)
    end

    def types(&block : DSL::Types ->) : self
      block.call(types)
      self
    end

    # Access the Crystal binary analysis and memory inspection helper.
    def crystal : CrystalHelper
      @crystal ||= CrystalHelper.new(self)
    end

    def crystal(&block : CrystalHelper ->) : self
      block.call(crystal)
      self
    end

    # --- Top-Level Ergonomic Shortcuts ---

    # Disassembles instructions returning typed Instruction models.
    def disassemble(count : Int32 = 10, at : Address? = nil) : Array(Model::Instruction)
      disasm.instructions(count: count, at: at)
    end

    # Disassembles instructions returning human-readable text.
    def disasm_text(count : Int32 = 10, at : Address? = nil) : String
      disasm.text(count: count, at: at)
    end

    # Decompiles current function or target to C-like pseudocode.
    def decompile(target : Address? = nil) : String
      disasm.decompile(target)
    end

    # Reads raw bytes from memory address as a Bytes slice.
    def read(address : Address, size : Int32) : Bytes
      memory.read(address.is_a?(UInt64) ? address : (AddressUtils.to_u64?(address) || 0_u64), size)
    end

    # Alias for read.
    def read_bytes(address : Address, size : Int32) : Bytes
      read(address, size)
    end

    # Reads a null-terminated string from memory address.
    def read_string(address : Address, max_len : Int32? = nil) : String
      memory.read_string(address, max_len)
    end

    # Reads a null-terminated C-string from memory address.
    def read_cstring(address : Address, max_len : Int32 = 256) : String
      memory.read_cstring(address, max_len)
    end

    # Reads an array of 64-bit pointers from memory address.
    def read_pointer_array(address : Address, count : Int32) : Array(UInt64)
      memory.read_pointer_array(address, count)
    end

    # Returns formatted hexdump text for human inspection.
    def hexdump(address : Address? = nil, size : Int32 = 64) : String
      addr_u64 = address ? (AddressUtils.to_u64?(address) || 0_u64) : nil
      memory.hexdump(addr_u64, size)
    end

    # Sets a software breakpoint at the given address or symbol.
    def breakpoint(target : Address) : self
      debug.breakpoint(target)
      self
    end

    # Removes a software breakpoint at the given address or symbol.
    def remove_breakpoint(target : Address) : self
      debug.remove_breakpoint(target)
      self
    end

    # Returns loaded binary modules in the target process.
    def modules : Array(Model::ModuleInfo)
      debug.modules
    end

    # Returns the binary module containing the specified address.
    def module_at(address : Address) : Model::ModuleInfo?
      debug.module_at(address)
    end

    # Returns the base load address of a specific loaded module by name.
    def base_address_of(module_name : String) : UInt64?
      debug.base_address_of(module_name)
    end

    # Returns the source location corresponding to an instruction address if mapped.
    def source_location_at(address : Address) : Lines::SourceLocation?
      addr_u64 = AddressUtils.to_u64?(address)
      return nil unless addr_u64
      crystal.lines.at(addr_u64)
    end

    # Closes the radare2 session.
    def close : Nil
      @transport.close
    end

    # Alias for close.
    def quit : Nil
      close
    end

    # Returns true if the session is closed.
    def closed? : Bool
      @transport.closed?
    end

    private def notify_command(command : String, duration : Time::Span, success : Bool) : Nil
      @command_listeners.each do |listener|
        listener.call(command, duration, success) rescue nil
      end
    end
  end
end
