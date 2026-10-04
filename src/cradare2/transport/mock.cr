require "./transport"

module Cradare2
  module Transport
    # A mock transport for testing without requiring a live radare2 process.
    class MockTransport < Base
      getter history : Array(String) = [] of String
      getter? closed : Bool = false

      @handlers : Array({String | Regex, Proc(String, String)}) = [] of {String | Regex, Proc(String, String)}
      @default_handler : Proc(String, String)?

      def initialize(@default_handler = nil)
      end

      # Convenience constructor accepting a default handler block.
      def self.new(&block : String -> String) : MockTransport
        mock = new
        mock.default(&block)
        mock
      end

      # Registers a mock response for an exact command string.
      def on(command : String, response : String) : self
        @handlers << {command, ->(_cmd : String) { response }}
        self
      end

      # Registers a dynamic mock block handler for an exact command string.
      def on(command : String, &block : String -> String) : self
        @handlers << {command, block}
        self
      end

      # Registers a mock dynamic block handler for a regex command match.
      def on(pattern : Regex, &block : String -> String) : self
        @handlers << {pattern, block}
        self
      end

      # Sets a default fallback block when no handler matches.
      def default(&block : String -> String) : self
        @default_handler = block
        self
      end

      def cmd(command : String) : String
        raise SessionClosedError.new("Cannot execute command on a closed radare2 session") if @closed
        @history << command

        @handlers.each do |pattern, handler|
          match = case pattern
                  when String
                    pattern == command
                  when Regex
                    command =~ pattern
                  else
                    false
                  end
          return handler.call(command) if match
        end

        if handler = @default_handler
          return handler.call(command)
        end

        # Default empty string response
        ""
      end

      def close : Nil
        @closed = true
      end

      def reset : Nil
        @history.clear
        @handlers.clear
        @default_handler = nil
        @closed = false
      end
    end
  end
end
