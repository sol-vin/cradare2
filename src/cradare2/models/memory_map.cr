require "json"

module Cradare2
  module Model
    # Represents a virtual memory map/region from radare2 `dmj`.
    struct MemoryMap
      include JSON::Serializable

      getter name : String = ""
      getter addr : UInt64 = 0_u64
      getter addr_end : UInt64 = 0_u64
      getter size : UInt64? = nil
      getter perm : String? = nil
      getter type : String? = nil

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
