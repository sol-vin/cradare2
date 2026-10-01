require "json"
require "../address"

module Cradare2
  module Model
    # Represents a telescoping register dereference entry from radare2 `drrj`.
    struct TelescopeEntry
      include JSON::Serializable

      getter reg : String
      getter value : String
      getter refstr : String? = nil
      getter role : String? = nil

      def initialize(
        @reg : String,
        @value : String,
        @refstr : String? = nil,
        @role : String? = nil,
      )
      end

      # Parses numeric pointer/register value as a 64-bit unsigned integer.
      def value_u64 : UInt64
        AddressUtils.to_u64?(@value) || 0_u64
      end

      def to_s(io : IO) : Nil
        r = @role ? "[#{@role}] " : ""
        ref = @refstr ? " -> #{@refstr}" : ""
        io << "#{r}#{@reg} = #{@value}#{ref}"
      end
    end
  end
end
