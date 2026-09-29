require "json"

module Cradare2
  module Model
    # Represents a code or data cross-reference (XREF) from radare2 xtj or xfj.
    struct Xref
      include JSON::Serializable

      @[JSON::Field(key: "from")]
      getter raw_from : UInt64? = nil

      @[JSON::Field(key: "to")]
      getter raw_to : UInt64? = nil

      @[JSON::Field(key: "type")]
      getter type : String = "CALL"

      @[JSON::Field(key: "opcode")]
      getter opcode : String? = nil

      @[JSON::Field(key: "fcn_addr")]
      getter function_address : UInt64? = nil

      @[JSON::Field(key: "fcn_name")]
      getter function_name : String? = nil

      @[JSON::Field(key: "ref")]
      getter ref : UInt64? = nil

      def initialize(
        @raw_from : UInt64? = nil,
        @raw_to : UInt64? = nil,
        @type : String = "CALL",
        @opcode : String? = nil,
        @function_address : UInt64? = nil,
        @function_name : String? = nil,
        @ref : UInt64? = nil,
      )
      end

      def from : UInt64
        @raw_from || 0_u64
      end

      def to : UInt64
        @raw_to || @ref || 0_u64
      end

      def call? : Bool
        type.upcase == "CALL"
      end

      def data? : Bool
        type.upcase == "DATA"
      end

      def jump? : Bool
        type.upcase.includes?("JMP")
      end
    end
  end
end
