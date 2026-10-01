require "json"
require "./memory_map"

module Cradare2
  module Model
    # Represents a loaded binary module (executable, shared library, DLL) within the target process.
    struct ModuleInfo
      include JSON::Serializable

      @[JSON::Field(key: "name")]
      getter name : String

      @[JSON::Field(key: "path")]
      getter path : String? = nil

      @[JSON::Field(key: "addr")]
      getter raw_addr : UInt64? = nil

      @[JSON::Field(key: "baddr")]
      getter raw_baddr : UInt64? = nil

      @[JSON::Field(key: "addr_end")]
      getter raw_addr_end : UInt64? = nil

      @[JSON::Field(key: "size")]
      getter raw_size : UInt64? = nil

      @[JSON::Field(ignore: true)]
      property regions : Array(MemoryMap) = [] of MemoryMap

      def initialize(
        @name : String,
        base_address : UInt64? = nil,
        end_address : UInt64? = nil,
        size : UInt64? = nil,
        @path : String? = nil,
        @regions : Array(MemoryMap) = [] of MemoryMap,
      )
        @raw_addr = base_address
        @raw_baddr = base_address
        @raw_addr_end = end_address
        @raw_size = size
      end

      # The base virtual memory load address of this module.
      def base_address : UInt64
        if baddr = @raw_baddr
          return baddr if baddr > 0
        end
        if addr = @raw_addr
          return addr if addr > 0
        end
        @regions.empty? ? 0_u64 : @regions.min_of(&.addr)
      end

      # Uniform address alias
      def address : UInt64
        base_address
      end

      # The upper boundary of the virtual memory occupied by this module.
      def end_address : UInt64
        if end_addr = @raw_addr_end
          return end_addr if end_addr > 0
        end
        if sz = @raw_size
          return base_address + sz if sz > 0
        end
        @regions.empty? ? base_address : @regions.max_of(&.addr_end)
      end

      # Total size in bytes of the module's mapped image in memory.
      def size : UInt64
        if sz = @raw_size
          return sz if sz > 0
        end
        end_address > base_address ? (end_address - base_address) : 0_u64
      end

      # Returns true if the specified virtual memory address falls within this module's bounds.
      def contains?(address : UInt64) : Bool
        address >= base_address && address < end_address
      end

      # Formatted display string
      def to_s(io : IO) : Nil
        io << @name << " [0x" << base_address.to_s(16) << " - 0x" << end_address.to_s(16) << "]"
      end
    end
  end
end
