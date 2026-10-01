require "./cradare2/version"
require "./cradare2/error"
require "./cradare2/util/locator"
require "./cradare2/util/demangler"
require "./cradare2/transport/transport"
require "./cradare2/transport/process"
require "./cradare2/transport/http"
require "./cradare2/transport/tcp"
require "./cradare2/transport/in_session"
require "./cradare2/transport/mock"
require "./cradare2/lines/source_location"
require "./cradare2/lines/source_reader"
require "./cradare2/lines/source_map"
require "./cradare2/lines/line_resolver"
require "./cradare2/lines/line_helper"
require "./cradare2/crystal"
require "./cradare2/client"
require "./cradare2/tui/explorer"

module Cradare2
  # Opens a radare2 session.
  #
  # Target options:
  # - nil / "" / "#!pipe" : Connects to the current radare2 in-session pipe (when run via `#!pipe`)
  # - "http://..." or "https://..." : Connects to a remote radare2 HTTP/REST server
  # - "tcp://..." : Connects to a remote radare2 TCP socket server
  # - File path or URI (e.g. "game.dll", "malloc://1024") : Spawns a local `radare2 -q0` process
  def self.open(
    target : String? = nil,
    flags : Array(String) = [] of String,
    debug : Bool = false,
    write : Bool = false,
    r2_path : String? = nil,
    timeout : Time::Span? = nil,
  ) : Client
    transport = build_transport(target, flags, debug, write, r2_path, timeout)
    Client.new(transport)
  end

  # Opens a radare2 session and yields it to the block, ensuring the session
  # is automatically closed when the block exits.
  def self.open(
    target : String? = nil,
    flags : Array(String) = [] of String,
    debug : Bool = false,
    write : Bool = false,
    r2_path : String? = nil,
    timeout : Time::Span? = nil,
    &block : Client -> U
  ) : U forall U
    client = open(target, flags, debug, write, r2_path, timeout)
    begin
      yield client
    ensure
      client.close
    end
  end

  # Creates a client backed by a `MockTransport` for testing and offline development.
  def self.mock(default_handler = nil) : Client
    transport = Transport::MockTransport.new(default_handler)
    Client.new(transport)
  end

  # Creates a mock client and yields it to the block.
  def self.mock(default_handler = nil, &block : Client -> U) : U forall U
    client = mock(default_handler)
    begin
      yield client
    ensure
      client.close
    end
  end

  private def self.build_transport(
    target : String?,
    flags : Array(String),
    debug : Bool,
    write : Bool,
    r2_path : String?,
    timeout : Time::Span?,
  ) : Transport::Base
    if target.nil? || target.empty? || target == "#!pipe"
      Transport::InSessionTransport.new(timeout: timeout)
    elsif target.starts_with?("http://") || target.starts_with?("https://")
      Transport::HttpTransport.new(target, timeout: timeout)
    elsif target.starts_with?("tcp://")
      Transport::TcpTransport.new(target, timeout: timeout)
    else
      Transport::ProcessTransport.new(
        target: target,
        flags: flags,
        debug: debug,
        write: write,
        r2_path: r2_path,
        timeout: timeout
      )
    end
  end
end

# Convenient top-level aliases
R2     = Cradare2
R2Pipe = Cradare2
