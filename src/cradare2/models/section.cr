require "json"

module Cradare2
  module Model
    # Represents an executable section/segment from radare2 `iSj`.
    struct Section
      include JSON::Serializable

      getter name : String = ""
      getter size : UInt64 = 0_u64
      getter vsize : UInt64? = nil
      getter perm : String? = nil
      getter flags : Int64? = nil
      getter paddr : UInt64? = nil
      getter vaddr : UInt64 = 0_u64
      getter entropy : Float64? = nil

      # Check if virtual address falls inside this section
      def contains?(address : UInt64) : Bool
        span = vsize || size
        address >= vaddr && address < (vaddr + span)
      end

      # Permission checks
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
