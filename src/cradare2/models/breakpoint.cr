require "json"

module Cradare2
  module Model
    # Represents a breakpoint from radare2 `dbj`.
    struct Breakpoint
      include JSON::Serializable

      @[JSON::Field(key: "addr")]
      getter raw_addr : UInt64? = nil

      @[JSON::Field(key: "baddr")]
      getter raw_baddr : UInt64? = nil

      getter size : Int32? = nil
      getter hw : Bool? = nil
      getter trace : Bool? = nil
      getter enabled : Bool? = nil
      getter name : String? = nil
      getter hits : Int32? = nil
      getter cond : String? = nil

      def offset : UInt64
        @raw_addr || @raw_baddr || 0_u64
      end

      def address : UInt64
        offset
      end

      def enabled? : Bool
        enabled != false
      end

      def hardware? : Bool
        hw == true
      end

      def hit_count : Int32
        hits || 0
      end
    end
  end
end
