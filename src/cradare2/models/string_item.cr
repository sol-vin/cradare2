require "json"

module Cradare2
  module Model
    # Represents a string found in the binary from `izj` or `izzj`.
    struct StringItem
      include JSON::Serializable

      getter string : String = ""
      getter vaddr : UInt64 = 0_u64
      getter paddr : UInt64? = nil
      getter size : UInt64? = nil
      getter length : UInt64? = nil
      getter section : String? = nil
      getter type : String? = nil

      def offset : UInt64
        vaddr
      end
    end
  end
end
