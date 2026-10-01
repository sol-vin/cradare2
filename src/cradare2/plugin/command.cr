require "../client"

module Cradare2
  module Plugin
    # Abstract base class for all radare2 plugin subcommands.
    abstract class Command
      getter name : String
      getter summary : String
      getter usage : String
      getter aliases : Array(String)

      def initialize(
        @name : String,
        @summary : String,
        @usage : String = "",
        @aliases : Array(String) = [] of String,
      )
        @usage = "crystal #{@name}" if @usage.empty?
      end

      # Executes the subcommand. Returns formatted text or JSON string when `json: true`.
      abstract def execute(client : Client, args : Array(String), json : Bool = false) : String

      # Utility helper to parse an address argument.
      protected def parse_address(str : String) : UInt64?
        AddressUtils.to_u64?(str)
      end
    end
  end
end
