require "json"

module Cradare2
  module Model
    # Represents a disassembled / analyzed function from radare2 `aflj` or `afij`.
    struct Function
      include JSON::Serializable

      @[JSON::Field(key: "offset")]
      getter raw_offset : UInt64? = nil

      @[JSON::Field(key: "addr")]
      getter raw_addr : UInt64? = nil

      getter name : String = ""
      getter size : UInt64 = 0_u64
      getter realsz : UInt64? = nil
      getter cc : Int32? = nil
      getter cost : Int32? = nil
      getter signature : String? = nil
      getter calltype : String? = nil
      getter nargs : Int32? = nil
      getter nlocals : Int32? = nil
      getter stackframe : Int32? = nil
      getter nbbs : Int32? = nil
      getter ninstrs : Int32? = nil
      getter noreturn : Bool? = nil
      getter recursive : Bool? = nil

      # Uniform offset / address helper
      def offset : UInt64
        @raw_offset || @raw_addr || 0_u64
      end

      # Address alias
      def address : UInt64
        offset
      end
    end
  end
end
