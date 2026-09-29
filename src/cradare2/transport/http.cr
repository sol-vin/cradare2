require "./transport"
require "http/client"
require "uri"

module Cradare2
  module Transport
    # Communicates with a radare2 HTTP/REST server (e.g., http://localhost:9090).
    class HttpTransport < Base
      getter uri : URI
      getter? closed : Bool = false
      @client : HTTP::Client

      def initialize(target : String, @timeout : Time::Span? = nil)
        @uri = URI.parse(target)
        unless @uri.scheme == "http" || @uri.scheme == "https"
          raise TransportError.new("Invalid HTTP URI scheme: #{@uri.scheme.inspect}")
        end

        host = @uri.host.presence
        unless host
          raise TransportError.new("Invalid HTTP URI: host missing")
        end
        port = @uri.port || (@uri.scheme == "https" ? 443 : 9090)
        tls = @uri.scheme == "https"

        @client = HTTP::Client.new(host, port, tls: tls)
        @client.read_timeout = @timeout if @timeout
        @client.connect_timeout = @timeout if @timeout
      end

      def cmd(command : String) : String
        raise SessionClosedError.new("Cannot execute command on a closed radare2 session") if @closed

        encoded_cmd = URI.encode_path_segment(command)
        path = "#{@uri.path.presence || ""}/cmd/#{encoded_cmd}"
        path = "/" + path.lstrip('/')

        response = @client.get(path)
        unless response.success?
          raise TransportError.new("HTTP request failed with status #{response.status_code}: #{response.body}")
        end

        response.body
      rescue ex : TransportError | SessionClosedError
        raise ex
      rescue ex
        raise TransportError.new("HTTP command execution error: #{ex.message}", cause: ex)
      end

      def close : Nil
        return if @closed
        @closed = true
        @client.close
      end
    end
  end
end
