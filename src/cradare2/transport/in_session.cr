require "./transport"

module Cradare2
  module Transport
    # Handles communication when running directly inside radare2 via `#!pipe`.
    # Reads/writes to the file descriptors or named pipes configured by radare2.
    class InSessionTransport < Base
      getter? closed : Bool = false
      @input : IO
      @output : IO
      @mutex : Mutex = Mutex.new

      def initialize(@timeout : Time::Span? = nil)
        @input, @output = resolve_ios
      end

      def cmd(command : String) : String
        raise SessionClosedError.new("Cannot execute command on a closed radare2 session") if @closed

        @mutex.synchronize do
          @output.puts(command)
          @output.flush

          response = @input.gets('\0', chomp: true)
          if response.nil?
            raise TransportError.new("Unexpected EOF while reading radare2 response")
          end
          response
        end
      rescue ex : TransportError | SessionClosedError
        raise ex
      rescue ex
        raise TransportError.new("In-session r2pipe communication error: #{ex.message}", cause: ex)
      end

      def close : Nil
        return if @closed
        @closed = true
        @input.close unless @input.closed?
        @output.close unless @output.closed?
      end

      private def resolve_ios : {IO, IO}
        if pipe_path = ENV["R2PIPE_PATH"]?
          file = File.open(pipe_path, "r+")
          return {file, file}
        end

        {% if flag?(:windows) %}
          if (in_fd_str = ENV["R2PIPE_IN"]?) && (out_fd_str = ENV["R2PIPE_OUT"]?)
            in_io = IO::FileDescriptor.new(in_fd_str.to_u64)
            out_io = IO::FileDescriptor.new(out_fd_str.to_u64)
            return {in_io, out_io}
          end
        {% else %}
          if (in_fd_str = ENV["R2PIPE_IN"]?) && (out_fd_str = ENV["R2PIPE_OUT"]?)
            in_fd = in_fd_str.to_i
            out_fd = out_fd_str.to_i
            in_io = IO::FileDescriptor.new(in_fd)
            out_io = IO::FileDescriptor.new(out_fd)
            return {in_io, out_io}
          end
        {% end %}

        raise TransportError.new("In-session r2pipe environment variables (R2PIPE_PATH or R2PIPE_IN/R2PIPE_OUT) not found")
      end
    end
  end
end
