module Cradare2
  # Base exception class for all Cradare2 errors.
  class Error < Exception
  end

  # Raised when communication with radare2 fails over the transport layer.
  class TransportError < Error
  end

  # Raised when radare2 or r2 executable cannot be located on the system.
  class BinaryNotFoundError < TransportError
  end

  # Raised when attempting to issue commands to a closed radare2 session.
  class SessionClosedError < Error
  end

  # Raised when parsing radare2 JSON responses fails.
  class ParseError < Error
  end

  # Raised when a radare2 command returns an error or unexpected status.
  class CommandError < Error
  end

  # Raised when an operation or command execution times out.
  class TimeoutError < Error
  end
end
