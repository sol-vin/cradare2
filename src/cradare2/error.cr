module Cradare2
  # Base exception class for all Cradare2 errors.
  class Error < Exception
  end

  # Raised when communication with radare2 fails over the transport layer.
  class TransportError < Error
  end

  # Raised when the child radare2 process exits or crashes unexpectedly.
  class ProcessTerminatedError < TransportError
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

  # Raised when symbol resolution fails.
  class SymbolResolutionError < Error
  end

  # Raised when reading or decoding runtime memory layouts fails.
  class MemoryInspectionError < Error
  end

  # Raised when defining or printing custom radare2 types/formats fails.
  class TypeDefinitionError < Error
  end
end
