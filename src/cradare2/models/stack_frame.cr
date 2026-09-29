require "json"

module Cradare2
  module Model
    # Represents a stack frame in a debug backtrace from radare2 `dbtj`.
    struct StackFrame
      include JSON::Serializable

      getter frame : Int32 = 0
      getter sp : UInt64 = 0_u64
      getter bp : UInt64? = nil

      @[JSON::Field(key: "addr")]
      getter raw_addr : UInt64? = nil

      @[JSON::Field(key: "pc")]
      getter raw_pc : UInt64? = nil

      @[JSON::Field(key: "fname")]
      getter raw_fname : String? = nil

      @[JSON::Field(key: "function")]
      getter raw_function : String? = nil

      getter offset : UInt64? = nil
      getter fcn_offset : UInt64? = nil

      def pc : UInt64
        @raw_pc || @raw_addr || 0_u64
      end

      def function : String
        @raw_function || @raw_fname || "unknown"
      end
    end
  end
end
