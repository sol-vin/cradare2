require "opal"
require "./cradare2/version"
require "./cradare2/error"
require "./cradare2/address"
require "./cradare2/options"
require "./cradare2/util/locator"
require "./cradare2/util/demangler"
require "./cradare2/util/cli_formatter"
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
require "./cradare2/util/script_builder"
require "./cradare2/util/doctor"
require "./cradare2/gdb/client"
require "./cradare2/client"
require "./cradare2/plugin/command"
require "./cradare2/plugin/commands/*"
require "./cradare2/plugin/dispatcher"
require "./cradare2/plugin/router"
require "./cradare2/plugin/server"
require "./cradare2/tui/explorer"

module Cradare2
  # Opens a radare2 session using an `Options` struct.
  def self.open(options : Options) : Client
    transport = if pid = options.attach_pid
                  Transport::ProcessTransport.new(
                    target: "",
                    flags: (options.flags.includes?("-p") ? options.flags : (["-p", pid.to_s] + options.flags)),
                    debug: true,
                    write: true,
                    r2_path: options.r2_path,
                    timeout: options.timeout
                  )
                else
                  build_transport(
                    options.target,
                    options.flags,
                    options.debug,
                    options.write,
                    options.r2_path,
                    options.timeout
                  )
                end
    client = Client.new(transport)
    client.analyze.all if options.auto_analyze
    client
  end

  # Opens a radare2 session with `Options` and yields it to a block, ensuring cleanup.
  def self.open(options : Options, &block : Client -> U) : U forall U
    client = open(options)
    begin
      yield client
    ensure
      client.close
    end
  end

  # Attaches radare2 in debug mode to a running process by PID.
  def self.attach(
    pid : Int32 | Int64,
    flags : Array(String) = [] of String,
    r2_path : String? = nil,
    timeout : Time::Span? = nil,
  ) : Client
    options = Options.new(
      target: "",
      flags: ["-p", pid.to_s] + flags,
      debug: true,
      write: true,
      r2_path: r2_path,
      timeout: timeout,
      attach_pid: pid.to_i64
    )
    open(options)
  end

  # Attaches radare2 in debug mode to a running process by PID and yields client to block.
  def self.attach(
    pid : Int32 | Int64,
    flags : Array(String) = [] of String,
    r2_path : String? = nil,
    timeout : Time::Span? = nil,
    &block : Client -> U
  ) : U forall U
    client = attach(pid, flags, r2_path, timeout)
    begin
      yield client
    ensure
      client.close
    end
  end

  # Opens a radare2 session configured with individual parameters.
  #
  # Target options:
  # - nil / "" / "#!pipe" : Connects to current radare2 in-session pipe (when run via `#!pipe`)
  # - "http://..." or "https://..." : Connects to remote radare2 HTTP server
  # - "tcp://..." : Connects to remote radare2 TCP socket server
  # - File path or URI (e.g. "game.dll", "malloc://1024") : Spawns a local `radare2 -q0` process
  def self.open(
    target : String? = nil,
    flags : Array(String) = [] of String,
    debug : Bool = false,
    write : Bool = false,
    r2_path : String? = nil,
    timeout : Time::Span? = nil,
  ) : Client
    options = Options.new(
      target: target,
      flags: flags,
      debug: debug,
      write: write,
      r2_path: r2_path,
      timeout: timeout
    )
    open(options)
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

  # Analyzes an in-memory byte slice using radare2, automatically handling temporary file lifecycle.
  def self.open_bytes(
    bytes : Bytes,
    arch : String? = nil,
    bits : Int32? = nil,
    cpu : String? = nil,
    flags : Array(String) = [] of String,
    &block : Client -> U
  ) : U forall U
    temp_file = File.tempfile("cradare2_buf", ".bin")
    begin
      File.write(temp_file.path, bytes)
      opts = Options.new(
        target: temp_file.path,
        flags: flags,
        arch: arch,
        bits: bits,
        cpu: cpu
      )
      open(opts, &block)
    ensure
      temp_file.delete rescue nil
    end
  end

  # Connects radare2 to a remote GDB stub (e.g. PCSX2, QEMU, gdbserver).
  def self.gdb(
    host : String = "127.0.0.1",
    port : Int32 = 1234,
    arch : String? = nil,
    bits : Int32? = nil,
    cpu : String? = nil,
    timeout : Time::Span? = nil,
    &block : Client -> U
  ) : U forall U
    opts = Options.new(
      timeout: timeout,
      arch: arch,
      bits: bits,
      cpu: cpu
    )
    opts.gdb_target(host, port)
    open(opts, &block)
  end

  # Runs toolchain and environment diagnostics.
  def self.doctor : Util::Doctor
    Util::Doctor.new.run
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
