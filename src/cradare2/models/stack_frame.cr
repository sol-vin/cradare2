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

      def initialize(
        @frame : Int32 = 0,
        @raw_pc : UInt64? = nil,
        @raw_function : String? = nil,
        @sp : UInt64 = 0_u64,
        @bp : UInt64? = nil,
        @raw_addr : UInt64? = nil,
        @raw_fname : String? = nil,
        @offset : UInt64? = nil,
        @fcn_offset : UInt64? = nil,
      )
      end

      def pc : UInt64
        @raw_pc || @raw_addr || 0_u64
      end

      def address : UInt64
        pc
      end

      def function : String
        @raw_function || @raw_fname || "unknown"
      end

      def function_name : String
        function
      end
    end
  end
end
