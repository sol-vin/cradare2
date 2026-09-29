require "json"

module Cradare2
  module Model
    # Represents a disassembled instruction from radare2 `pdj` or `pdfj`.
    struct Instruction
      include JSON::Serializable

      @[JSON::Field(key: "addr")]
      getter raw_addr : UInt64? = nil

      @[JSON::Field(key: "offset")]
      getter raw_offset : UInt64? = nil

      getter size : Int32 = 0
      getter opcode : String = ""
      getter disasm : String? = nil
      getter bytes : String? = nil
      getter type : String? = nil
      getter family : String? = nil
      getter jump : UInt64? = nil
      getter fail : UInt64? = nil
      getter comment : String? = nil
      getter flags : Array(String)? = nil

      def offset : UInt64
        @raw_offset || @raw_addr || 0_u64
      end

      def address : UInt64
        offset
      end

      # Human readable disassembly line
      def to_s : String
        disasm || opcode
      end
    end
  end
end
