module Cradare2
  # Unified type alias for addresses across all modules and DSLs.
  alias Address = UInt64 | Int64 | Int32 | String

  # Utility methods for formatting and parsing addresses.
  module AddressUtils
    # Formats an address into a canonical hex string ("0x140001000") or symbol name.
    def self.to_hex(addr : Address) : String
      case addr
      when Int
        addr < 0 ? "0x0" : "0x#{addr.to_s(16)}"
      when String
        if u = to_u64?(addr)
          "0x#{u.to_s(16)}"
        else
          addr
        end
      else
        addr.to_s
      end
    end

    # Parses an address into an unsigned 64-bit integer, or returns nil if it is an unresolved symbol name.
    def self.to_u64?(addr : Address) : UInt64?
      case addr
      when UInt64
        addr
      when Int
        addr < 0 ? nil : addr.to_u64
      when String
        s = addr.strip
        if s.starts_with?("0x") || s.starts_with?("0X")
          s[2..].to_u64?(16)
        elsif s.ends_with?('h') || s.ends_with?('H')
          s[0...-1].to_u64?(16)
        else
          s.to_u64? || s.to_u64?(16)
        end
      end
    end

    # Parses an address into an unsigned 64-bit integer, defaulting to 0_u64 if parsing fails.
    def self.to_u64(addr : Address) : UInt64
      to_u64?(addr) || 0_u64
    end

    # Parses an address into an unsigned 64-bit integer, raising ArgumentError if parsing fails.
    def self.to_u64!(addr : Address) : UInt64
      to_u64?(addr) || raise ArgumentError.new("Cannot parse address: #{addr}")
    end
  end
end
