require "json"

module Cradare2
  module Model
    # Represents a basic block within a function from radare2 `afbj`.
    struct BasicBlock
      include JSON::Serializable

      @[JSON::Field(key: "addr")]
      getter raw_addr : UInt64? = nil

      @[JSON::Field(key: "offset")]
      getter raw_offset : UInt64? = nil

      getter size : UInt64 = 0_u64
      getter jump : UInt64? = nil
      getter fail : UInt64? = nil
      getter ninstrs : Int32? = nil

      def offset : UInt64
        @raw_offset || @raw_addr || 0_u64
      end

      def address : UInt64
        offset
      end
    end
  end
end
