require "json"

module Cradare2
  module Model
    # Represents a virtual memory map/region from radare2 `dmj`.
    struct MemoryMap
      include JSON::Serializable

      getter name : String = ""

      @[JSON::Field(key: "addr")]
      getter raw_addr : UInt64? = nil

      @[JSON::Field(key: "from")]
      getter raw_from : UInt64? = nil

      @[JSON::Field(key: "addr_end")]
      getter raw_addr_end : UInt64? = nil

      @[JSON::Field(key: "to")]
      getter raw_to : UInt64? = nil

      getter size : UInt64? = nil
      getter perm : String? = nil
      getter type : String? = nil

      def initialize(
        @raw_addr : UInt64? = 0_u64,
        @raw_addr_end : UInt64? = 0_u64,
        @perm : String? = nil,
        @name : String = "",
        @size : UInt64? = nil,
        @type : String? = nil,
        @raw_from : UInt64? = nil,
        @raw_to : UInt64? = nil,
      )
      end

      def addr : UInt64
        @raw_addr || @raw_from || 0_u64
      end

      def addr_end : UInt64
        @raw_addr_end || @raw_to || (addr + (size || 0_u64))
      end

      def span : UInt64
        size || (addr_end > addr ? addr_end - addr : 0_u64)
      end

      def contains?(address : UInt64) : Bool
        address >= addr && address < addr_end
      end

      def readable? : Bool
        perm.try(&.includes?('r')) || false
      end

      def writable? : Bool
        perm.try(&.includes?('w')) || false
      end

      def executable? : Bool
        perm.try(&.includes?('x')) || false
      end
    end
  end
end
