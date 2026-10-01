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

      @[JSON::Field(key: "data")]
      getter data : String? = nil

      @[JSON::Field(key: "cmd")]
      getter cmd : String? = nil

      getter perm : String? = nil
      getter valid : Bool? = nil
      getter module : String? = nil

      def initialize(
        @raw_addr : UInt64? = nil,
        @raw_baddr : UInt64? = nil,
        @size : Int32? = nil,
        @hw : Bool? = nil,
        @trace : Bool? = nil,
        @enabled : Bool? = true,
        @name : String? = nil,
        @hits : Int32? = nil,
        @cond : String? = nil,
        @data : String? = nil,
        @cmd : String? = nil,
        @perm : String? = nil,
        @valid : Bool? = true,
        @module : String? = nil,
      )
      end

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

      def command : String?
        @cmd || (@data.try { |d| d.empty? ? nil : d })
      end

      def has_command? : Bool
        !command.nil?
      end

      def conditional? : Bool
        !@cond.nil? && !@cond.not_nil!.empty?
      end

      def watchpoint? : Bool
        if p = @perm
          (p.includes?('w') || p.includes?('r')) && !p.includes?('x')
        else
          false
        end
      end

      def software? : Bool
        !hardware? && !watchpoint?
      end

      def tracepoint? : Bool
        trace == true
      end

      def valid? : Bool
        valid != false
      end
    end
  end
end
