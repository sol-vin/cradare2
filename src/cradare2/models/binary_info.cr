require "json"

module Cradare2
  module Model
    # Core binary file metadata returned by radare2 `ij` command.
    struct CoreInfo
      include JSON::Serializable

      getter file : String? = nil
      getter size : UInt64? = nil
      getter format : String? = nil
      getter type : String? = nil
      getter mode : String? = nil
      getter block : Int32? = nil
      getter humansz : String? = nil
    end

    # Binary architecture and header metadata returned by radare2 `ij` command.
    struct BinInfo
      include JSON::Serializable

      getter arch : String? = nil
      getter bits : Int32? = nil
      getter os : String? = nil
      getter endian : String? = nil
      getter baddr : UInt64? = nil
      getter binsz : UInt64? = nil
      getter bintype : String? = nil
      getter compiled : String? = nil
      getter compiler : String? = nil
      getter machine : String? = nil
      getter canary : Bool? = nil
      getter nx : Bool? = nil
      getter pic : Bool? = nil
      getter relocs : Bool? = nil
      getter stripped : Bool? = nil
      getter static : Bool? = nil
      getter crypto : Bool? = nil
      getter sanitize : Bool? = nil
      getter subsys : String? = nil
    end

    # Complete target information model combining core and bin sections.
    struct BinaryInfo
      include JSON::Serializable

      getter core : CoreInfo? = nil
      getter bin : BinInfo? = nil

      def initialize(@core : CoreInfo? = nil, @bin : BinInfo? = nil)
      end

      # Convenience helper: architecture name
      def arch : String
        bin.try(&.arch) || "unknown"
      end

      # Convenience helper: word bit size (e.g. 32 or 64)
      def bits : Int32
        bin.try(&.bits) || 0
      end

      # Convenience helper: target operating system
      def os : String
        bin.try(&.os) || "unknown"
      end

      # Convenience helper: base load address
      def base_address : UInt64
        bin.try(&.baddr) || 0_u64
      end

      # Convenience helper: binary file format (e.g., pe, elf, mach0)
      def format : String
        core.try(&.format) || bin.try(&.bintype) || "unknown"
      end

      # Convenience helper: endianness
      def endian : String
        bin.try(&.endian) || "little"
      end

      # Convenience helper: check if 64-bit
      def bits64? : Bool
        bits == 64
      end

      # Convenience helper: check if position independent executable/dll
      def pic? : Bool
        bin.try(&.pic) == true
      end
    end
  end
end
