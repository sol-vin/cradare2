require "./dispatcher"

module Cradare2
  module Plugin
    # Sustained interactive command dispatch loop for radare2 pipe sessions (`#!pipe`).
    #
    # Reads command lines from an input IO, dispatches them through the `CommandDispatcher`,
    # and writes responses to the output IO until termination or EOF.
    module Server
      # Runs the interactive dispatch loop reading from `in_io` and writing to `out_io`.
      def self.run(dispatcher : CommandDispatcher, in_io : IO = STDIN, out_io : IO = STDOUT) : Nil
        while line = in_io.gets
          trimmed = line.strip
          break if trimmed == "q" || trimmed == "quit" || trimmed == "exit"
          next if trimmed.empty?

          output = dispatcher.dispatch(trimmed)
          out_io.puts(output)
          out_io.flush
        end
      end
    end
  end
end
