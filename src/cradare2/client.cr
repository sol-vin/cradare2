require "json"
require "./error"
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
require "./models/thread"
require "./util/demangler"
require "./dsl/analysis"
require "./dsl/disasm"
require "./dsl/memory"
require "./dsl/debugger"

module Cradare2
  # The central client representing an open radare2 session.
  class Client
    getter transport : Transport::Base

    @analysis : DSL::Analysis?
    @disasm : DSL::Disassembly?
    @memory : DSL::Memory?
    @debugger : DSL::Debugger?

    def initialize(@transport : Transport::Base)
    end

    # Executes a command string in radare2 and returns the raw output string.
    def cmd(command : String) : String
      @transport.cmd(command)
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

    # Seeks to the specified target address or symbol (s <target>).
    def seek(target : UInt64 | Int32 | Int64 | String) : self
      target_str = target.is_a?(Int) ? "0x#{target.to_s(16)}" : target
      cmd("s #{target_str}")
      self
    end

    # Returns the current seek position / offset.
    def current_offset : UInt64
      res = cmd("s").strip
      if res.starts_with?("0x") || res.starts_with?("0X")
        res[2..].to_u64?(16) || 0_u64
      else
        res.to_u64? || 0_u64
      end
    end

    # Returns binary metadata (ij).
    def info : Model::BinaryInfo
      cmdj("ij", as: Model::BinaryInfo)
    rescue
      Model::BinaryInfo.new
    end

    # Returns analyzed functions (aflj).
    def functions : Array(Model::Function)
      cmdj("aflj", as: Array(Model::Function))
    rescue
      [] of Model::Function
    end

    # Returns all symbols in the binary (isj).
    def symbols : Array(Model::Symbol)
      cmdj("isj", as: Array(Model::Symbol))
    rescue
      [] of Model::Symbol
    end

    # Returns exported symbols (iEj).
    def exports : Array(Model::Export)
      cmdj("iEj", as: Array(Model::Export))
    rescue
      [] of Model::Export
    end

    # Returns imported symbols (iij).
    def imports : Array(Model::Import)
      cmdj("iij", as: Array(Model::Import))
    rescue
      [] of Model::Import
    end

    # Returns binary sections (iSj).
    def sections : Array(Model::Section)
      cmdj("iSj", as: Array(Model::Section))
    rescue
      [] of Model::Section
    end

    # Returns strings in data sections (izj).
    def strings : Array(Model::StringItem)
      cmdj("izj", as: Array(Model::StringItem))
    rescue
      [] of Model::StringItem
    end

    # Returns strings from the entire binary (izzj).
    def all_strings : Array(Model::StringItem)
      cmdj("izzj", as: Array(Model::StringItem))
    rescue
      [] of Model::StringItem
    end

    # Demangles a symbol using radare2 and internal caching.
    def demangle(symbol : String) : String
      Util::Demangler.demangle(symbol, @transport)
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
  end
end
