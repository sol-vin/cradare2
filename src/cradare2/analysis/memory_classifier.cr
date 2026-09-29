require "../models/memory_map"
require "../models/register"

module Cradare2
  module Analysis
    # Semantic memory classification types for native process memory regions.
    enum MemoryRegionType
      Code
      Stack
      Heap
      DynamicLibrary
      SystemCRT
      NullLow
      Unmapped
    end

    # Represents an analyzed memory address with architectural classification.
    struct ClassifiedAddress
      getter address : UInt64
      getter region_type : MemoryRegionType
      getter module_name : String?
      getter permissions : String?
      getter nearest_symbol : String?

      def initialize(
        @address : UInt64,
        @region_type : MemoryRegionType,
        @module_name : String? = nil,
        @permissions : String? = nil,
        @nearest_symbol : String? = nil,
      )
      end

      def null_or_low? : Bool
        @region_type == MemoryRegionType::NullLow
      end

      def unmapped? : Bool
        @region_type == MemoryRegionType::Unmapped
      end

      def executable? : Bool
        @permissions.try(&.includes?('x')) == true
      end

      def to_s : String
        mod = @module_name ? "[#{@module_name}] " : ""
        perm = @permissions ? "(#{@permissions}) " : ""
        sym = @nearest_symbol ? "-> #{@nearest_symbol}" : ""
        "0x#{@address.to_s(16)}: #{mod}#{@region_type} #{perm}#{sym}".strip
      end
    end

    # Analyzed CPU registers with classified memory regions and pattern detection.
    struct RegisterAnalysis
      getter pc : ClassifiedAddress
      getter sp : ClassifiedAddress
      getter bp : ClassifiedAddress
      getter registers : Hash(String, ClassifiedAddress)

      def initialize(
        @pc : ClassifiedAddress,
        @sp : ClassifiedAddress,
        @bp : ClassifiedAddress,
        @registers : Hash(String, ClassifiedAddress) = {} of String => ClassifiedAddress,
      )
      end

      # Identifies probable root cause pattern for crash
      def probable_cause : Symbol
        # 1. Null pointer / low address branch or dereference
        if @pc.null_or_low?
          return :null_branch
        end

        # Check general registers for null dereference targets
        @registers.each do |name, classified|
          if classified.null_or_low? && ["rcx", "rdi", "rsi", "rax", "rdx", "ecx", "eax"].includes?(name)
            return :null_dereference
          end
        end

        # 2. Wild jump / unmapped execution address
        if @pc.unmapped?
          return :wild_jump
        end

        # 3. Stack corruption
        if @sp.unmapped? || @sp.null_or_low?
          return :stack_corruption
        end

        :access_violation
      end
    end

    # Engine for classifying raw pointers and process registers against memory maps.
    class MemoryClassifier
      getter maps : Array(Model::MemoryMap)

      def initialize(@maps : Array(Model::MemoryMap) = [] of Model::MemoryMap)
      end

      # Classifies an arbitrary 64-bit or 32-bit address
      def classify(address : UInt64, nearest_symbol : String? = nil) : ClassifiedAddress
        # Check null or low page range (e.g. 0x0 .. 0x1000)
        if address <= 0x1000_u64
          return ClassifiedAddress.new(
            address: address,
            region_type: MemoryRegionType::NullLow,
            module_name: nil,
            permissions: "---",
            nearest_symbol: nearest_symbol
          )
        end

        # Find matching memory map
        matching = @maps.find { |m| m.contains?(address) }
        unless matching
          return ClassifiedAddress.new(
            address: address,
            region_type: MemoryRegionType::Unmapped,
            module_name: nil,
            permissions: "---",
            nearest_symbol: nearest_symbol
          )
        end

        name = matching.name
        perm = matching.perm || "---"
        region_type = classify_region_type(name, perm)

        ClassifiedAddress.new(
          address: address,
          region_type: region_type,
          module_name: File.basename(name),
          permissions: perm,
          nearest_symbol: nearest_symbol
        )
      end

      # Analyzes a full set of CPU registers
      def analyze(regs : Model::Registers) : RegisterAnalysis
        reg_map = {} of String => ClassifiedAddress

        pc_class = classify(regs.pc)
        sp_class = classify(regs.sp)
        bp_class = classify(regs.bp)

        regs.all_registers.each do |name, val|
          reg_map[name.downcase] = classify(val)
        end

        RegisterAnalysis.new(
          pc: pc_class,
          sp: sp_class,
          bp: bp_class,
          registers: reg_map
        )
      end

      private def classify_region_type(name : String, perm : String) : MemoryRegionType
        down = name.downcase

        if down.includes?("[stack]") || down.includes?("stack")
          MemoryRegionType::Stack
        elsif down.includes?("[heap]") || down.includes?("malloc") || down.includes?("heap")
          MemoryRegionType::Heap
        elsif down.includes?("ntdll") || down.includes?("kernel32") || down.includes?("msvcrt") ||
              down.includes?("ucrtbase") || down.includes?("libc") || down.includes?("ld.so")
          MemoryRegionType::SystemCRT
        elsif perm.includes?('x')
          MemoryRegionType::Code
        elsif down.ends_with?(".dll") || down.ends_with?(".so") || down.ends_with?(".dylib")
          MemoryRegionType::DynamicLibrary
        else
          MemoryRegionType::Heap
        end
      end
    end
  end
end
