require "./transport"
require "../util/locator"
require "../error"

module Cradare2
  module Transport
    # Spawns a local radare2 child process using `-q0` null-byte delimited pipe mode.
    # Supported on Windows, Linux, and macOS.
    class ProcessTransport < Base
      getter target : String
      getter process : Process
      getter? closed : Bool = false

      @input : IO
      @output : IO
      @error : IO?
      @mutex : Mutex = Mutex.new

      def initialize(
        @target : String,
        flags : Array(String) = [] of String,
        debug : Bool = false,
        write : Bool = false,
        r2_path : String? = nil,
        @timeout : Time::Span? = nil,
      )
        bin = Util::Locator.find_r2(r2_path)

        args = [] of String
        args.concat(flags)
        args << "-d" if debug
        args << "-w" if write
        args << "-q0"
        args << @target

        @process = spawn_process(bin, args)

        @input = @process.input
        @output = @process.output
        @error = @process.error?

        # Initial handshake: r2 -q0 outputs an initial null-byte delimiter upon startup
        read_handshake
      end

      # Executes an r2 command string and returns its output up to the null byte terminator.
      def cmd(command : String) : String
        raise SessionClosedError.new("Cannot execute command on a closed radare2 session") if @closed

        @mutex.synchronize do
          write_command(command)
          read_response
        end
      end

      # Closes the r2 session by sending "q!" and terminating the child process.
      def close : Nil
        return if @closed
        @closed = true

        @mutex.synchronize do
          begin
            if @process.exists?
              @input.puts("q!")
              @input.flush
            end
          rescue
            # Ignore write failure during shutdown
          ensure
            cleanup_process
          end
        end
      end

      private def write_command(command : String) : Nil
        @input.puts(command)
        @input.flush
      rescue ex
        raise TransportError.new("Failed to send command to radare2: #{ex.message}", cause: ex)
      end

      private def read_response : String
        if span = @timeout
          channel = Channel(Tuple(String?, Exception?)).new(1)
          spawn do
            begin
              res = @output.gets('\0', chomp: true)
              channel.send({res, nil})
            rescue ex
              channel.send({nil, ex})
            end
          end

          select
          when result = channel.receive
            str, err = result
            raise err if err
            if str.nil?
              err_diag = read_stderr_diagnostic
              raise ProcessTerminatedError.new("Unexpected EOF while reading radare2 response (process may have crashed or exited)#{err_diag}")
            end
            str
          when timeout(span)
            raise TimeoutError.new("Radare2 command timed out after #{span.total_seconds} seconds")
          end
        else
          response = @output.gets('\0', chomp: true)
          if response.nil?
            err_diag = read_stderr_diagnostic
            raise ProcessTerminatedError.new("Unexpected EOF while reading radare2 response (process may have crashed or exited)#{err_diag}")
          end
          response
        end
      rescue ex : TransportError | TimeoutError
        raise ex
      rescue ex
        raise TransportError.new("Error reading response from radare2: #{ex.message}", cause: ex)
      end

      private def read_handshake : Nil
        initial = if span = @timeout
                    channel = Channel(Tuple(String?, Exception?)).new(1)
                    spawn do
                      begin
                        res = @output.gets('\0', chomp: true)
                        channel.send({res, nil})
                      rescue ex
                        channel.send({nil, ex})
                      end
                    end

                    select
                    when result = channel.receive
                      str, err = result
                      raise err if err
                      str
                    when timeout(span)
                      raise TimeoutError.new("Startup handshake timed out after #{span.total_seconds} seconds")
                    end
                  else
                    @output.gets('\0', chomp: true)
                  end

        if initial.nil?
          err_diag = read_stderr_diagnostic
          raise ProcessTerminatedError.new("Failed to receive initial startup handshake from radare2 process#{err_diag}")
        end
      end

      private def read_stderr_diagnostic : String
        if err_io = @error
          begin
            # Read whatever error output is currently available without blocking
            err_text = err_io.gets_to_end.strip
            return "\nRadare2 stderr:\n#{err_text}" unless err_text.empty?
          rescue
          end
        end
        ""
      end

      private def cleanup_process : Nil
        begin
          @input.close unless @input.closed?
        rescue
        end

        begin
          @output.close unless @output.closed?
        rescue
        end

        begin
          @error.try { |e| e.close unless e.closed? }
        rescue
        end

        begin
          if @process.exists?
            @process.wait
          end
        rescue
          begin
            @process.terminate(graceful: false) if @process.exists?
          rescue
          end
        end
      end

      private def spawn_process(bin : String, args : Array(String)) : Process
        Process.new(
          command: bin,
          args: args,
          input: Process::Redirect::Pipe,
          output: Process::Redirect::Pipe,
          error: Process::Redirect::Pipe
        )
      rescue ex
        raise TransportError.new("Failed to spawn radare2 process (#{bin}): #{ex.message}", cause: ex)
      end
    end
  end
end
