require "json"
require "../client"
require "../models/symbol"
require "../models/instruction"
require "../models/function"

module Cradare2
  module Bridge
    # Tier 1: Core Models
    struct ElfSymbolEntry
      include JSON::Serializable

      property name : String
      property demangled : String
      property address : UInt64
      property size : UInt64
      property type : String
      property binding : String

      def initialize(
        @name : String,
        @demangled : String,
        @address : UInt64,
        @size : UInt64,
        @type : String = "FUNC",
        @binding : String = "GLOBAL",
      )
      end
    end

    struct DisassembledSymbol
      include JSON::Serializable

      property symbol : ElfSymbolEntry
      property instructions : Array(Model::Instruction)
      property calls : Array(UInt64)
      property jumps : Array(UInt64)
      property is_mips : Bool

      def initialize(
        @symbol : ElfSymbolEntry,
        @instructions : Array(Model::Instruction),
        @calls : Array(UInt64) = [] of UInt64,
        @jumps : Array(UInt64) = [] of UInt64,
        @is_mips : Bool = false,
      )
      end

      def total_bytes : UInt64
        @instructions.sum(&.size.to_u64)
      end

      def instruction_count : Int32
        @instructions.size
      end
    end

    struct ElfTelemetry
      include JSON::Serializable

      property binary_path : String
      property arch : String
      property total_symbols : Int32
      property functions_disassembled : Int32
      property total_instructions : Int32
      property duration_ms : Float64

      def initialize(
        @binary_path : String,
        @arch : String,
        @total_symbols : Int32,
        @functions_disassembled : Int32,
        @total_instructions : Int32,
        @duration_ms : Float64,
      )
      end

      def throughput_ips : Float64
        return 0.0 if @duration_ms <= 0.0
        (@total_instructions.to_f / (@duration_ms / 1000.0))
      end
    end

    # Tier 1: Core Engine
    class ElfBridge
      getter client : Client
      property binary_path : String
      property filter_type : String?
      property min_size : UInt64
      property max_symbols : Int32
      property pattern : Regex?

      def initialize(@client : Client, @binary_path : String = "binary.elf")
        @filter_type = "FUNC"
        @min_size = 0_u64
        @max_symbols = 500
        @pattern = nil
      end

      # Extracts symbol table entries from r2
      def extract_symbols : Array(ElfSymbolEntry)
        symbols = @client.symbols
        symbols.compact_map do |sym|
          type_str = sym.type || ""
          next if @filter_type && type_str.upcase != @filter_type.not_nil!.upcase
          size_val = sym.size || 0_u64
          next if size_val < @min_size
          demang = sym.demangled || sym.name
          if pat = @pattern
            next unless sym.name =~ pat || demang =~ pat
          end

          ElfSymbolEntry.new(
            name: sym.name,
            demangled: demang,
            address: sym.vaddr,
            size: size_val,
            type: type_str,
            binding: sym.bind || "GLOBAL"
          )
        end
      end

      # Disassembles a specific symbol by name or address
      def disassemble_symbol(sym : ElfSymbolEntry) : DisassembledSymbol
        addr_hex = "0x#{sym.address.to_s(16)}"
        count = sym.size > 0 ? (sym.size // 4).clamp(1, 100).to_i32 : 16

        instructions = begin
          @client.disassemble(count, at: sym.address)
        rescue
          [] of Model::Instruction
        end

        calls = [] of UInt64
        jumps = [] of UInt64

        instructions.each do |inst|
          if inst.type == "call" && inst.jump
            calls << inst.jump.not_nil!
          elsif (inst.type == "jmp" || inst.type == "cjmp") && inst.jump
            jumps << inst.jump.not_nil!
          end
        end

        # Detect MIPS R5900 Emotion Engine or standard MIPS
        is_mips = instructions.any? do |i|
          i.opcode.starts_with?("jal") || i.opcode.starts_with?("lui") || i.opcode.starts_with?("sq") || i.opcode.starts_with?("lq")
        end

        DisassembledSymbol.new(
          symbol: sym,
          instructions: instructions,
          calls: calls,
          jumps: jumps,
          is_mips: is_mips
        )
      end

      # Batch disassembles all filtered symbols and records telemetry
      def disassemble_all : Tuple(Array(DisassembledSymbol), ElfTelemetry)
        start_time = Time.instant
        symbols = extract_symbols.first(@max_symbols)

        results = symbols.map do |sym|
          disassemble_symbol(sym)
        end

        elapsed = (Time.instant - start_time).total_milliseconds
        total_instructions = results.sum(&.instruction_count)

        arch = begin
          @client.info.arch
        rescue
          "mips"
        end

        telemetry = ElfTelemetry.new(
          binary_path: @binary_path,
          arch: arch,
          total_symbols: symbols.size,
          functions_disassembled: results.size,
          total_instructions: total_instructions,
          duration_ms: elapsed
        )

        {results, telemetry}
      end
    end
  end

  # Tier 2: Declarative Builder DSL
  def self.elf_bridge(client : Client, binary_path : String = "binary.elf", &block : Bridge::ElfBridge -> Nil) : Tuple(Array(Bridge::DisassembledSymbol), Bridge::ElfTelemetry)
    bridge = Bridge::ElfBridge.new(client, binary_path)
    yield bridge
    bridge.disassemble_all
  end
end

class Cradare2::Client
  def elf_bridge(binary_path : String = "binary.elf") : Cradare2::Bridge::ElfBridge
    Cradare2::Bridge::ElfBridge.new(self, binary_path)
  end
end
