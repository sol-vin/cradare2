require "json"

module Cradare2
  module Model
    # Represents a radare2 flag (name, offset, size) from `fj`.
    struct Flag
      include JSON::Serializable

      getter name : String

      @[JSON::Field(key: "offset")]
      getter raw_offset : UInt64? = nil

      @[JSON::Field(key: "addr")]
      getter raw_addr : UInt64? = nil

      getter size : UInt64 = 0_u64
      getter realname : String? = nil
      getter demangled : String? = nil

      def initialize(
        @name : String,
        offset : UInt64 = 0_u64,
        @size : UInt64 = 0_u64,
        @realname : String? = nil,
        @demangled : String? = nil,
      )
        @raw_offset = offset
        @raw_addr = offset
      end

      def offset : UInt64
        @raw_offset || @raw_addr || 0_u64
      end

      def address : UInt64
        offset
      end
    end
  end
end
