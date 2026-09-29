module Cradare2
  module Transport
    # Base abstract class for all radare2 communication transports.
    abstract class Base
      # Executes a command string in radare2 and returns the response string.
      abstract def cmd(command : String) : String

      # Closes the transport and releases any associated resources.
      abstract def close : Nil

      # Returns true if the transport has been closed.
      abstract def closed? : Bool

      # Optional timeout for command execution.
      property timeout : Time::Span?
    end
  end
end
