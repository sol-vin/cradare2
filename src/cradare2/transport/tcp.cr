require "./transport"
require "socket"
require "uri"

module Cradare2
  module Transport
    # Communicates with a radare2 instance over a raw TCP socket (e.g., tcp://localhost:9090).
    class TcpTransport < Base
      getter uri : URI
      getter? closed : Bool = false
      @socket : TCPSocket
      @mutex : Mutex = Mutex.new

      def initialize(target : String, @timeout : Time::Span? = nil)
        @uri = URI.parse(target)
        unless @uri.scheme == "tcp"
          raise TransportError.new("Invalid TCP URI scheme: #{@uri.scheme.inspect}")
        end

        host = @uri.host.presence
        unless host
          raise TransportError.new("Invalid TCP URI: host missing")
        end
        port = @uri.port
        unless port
          raise TransportError.new("Missing port in TCP URI: #{target}")
        end

        @socket = connect_socket(host, port)
      end

      def cmd(command : String) : String
        raise SessionClosedError.new("Cannot execute command on a closed radare2 session") if @closed

        @mutex.synchronize do
          @socket.puts(command)
          @socket.flush

          response = @socket.gets('\0', chomp: true)
          if response.nil?
            raise TransportError.new("Connection closed by remote radare2 server")
          end
          response
        end
      rescue ex : TransportError | SessionClosedError
        raise ex
      rescue ex
        raise TransportError.new("TCP communication error: #{ex.message}", cause: ex)
      end

      def close : Nil
        return if @closed
        @closed = true
        @socket.close unless @socket.closed?
      end

      private def connect_socket(host : String, port : Int32) : TCPSocket
        socket = TCPSocket.new(host, port)
        socket.read_timeout = @timeout if @timeout
        socket.sync = true
        socket
      rescue ex
        raise TransportError.new("Failed to connect to TCP server at #{host}:#{port}: #{ex.message}", cause: ex)
      end
    end
  end
end
