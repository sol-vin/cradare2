module Cradare2
  # Configuration options for establishing a radare2 session.
  class Options
    property target : String?
    property flags : Array(String)
    property debug : Bool
    property write : Bool
    property r2_path : String?
    property timeout : Time::Span?
    property attach_pid : Int64?
    property source_paths : Array(String)
    property path_mappings : Hash(String, String)
    property auto_analyze : Bool
    property log_commands : Bool
    property arch : String?
    property bits : Int32?
    property cpu : String?
    property eval_commands : Array(String)

    def initialize(
      @target : String? = nil,
      @flags : Array(String) = [] of String,
      @debug : Bool = false,
      @write : Bool = false,
      @r2_path : String? = nil,
      @timeout : Time::Span? = nil,
      @attach_pid : Int64? = nil,
      @source_paths : Array(String) = [] of String,
      @path_mappings : Hash(String, String) = Hash(String, String).new,
      @auto_analyze : Bool = false,
      @log_commands : Bool = false,
      @arch : String? = nil,
      @bits : Int32? = nil,
      @cpu : String? = nil,
      @eval_commands : Array(String) = [] of String,
    )
    end

    # Fluent builder helper
    def self.build(&block : Options -> Nil) : Options
      opts = Options.new
      yield opts
      opts
    end

    def target(val : String?) : self
      @target = val
      self
    end

    def debug_mode(enabled : Bool = true) : self
      @debug = enabled
      self
    end

    def write_mode(enabled : Bool = true) : self
      @write = enabled
      self
    end

    def read_only_mode : self
      @write = false
      self
    end

    def timeout(span : Time::Span?) : self
      @timeout = span
      self
    end

    def add_flag(flag : String) : self
      @flags << flag
      self
    end

    def add_flags(flags : Array(String)) : self
      @flags.concat(flags)
      self
    end

    def r2_path(path : String?) : self
      @r2_path = path
      self
    end

    def skip_analysis : self
      @auto_analyze = false
      self
    end

    def analyze_on_open(enabled : Bool = true) : self
      @auto_analyze = enabled
      self
    end

    def attach_pid(val : Int32 | Int64?) : self
      @attach_pid = val ? val.to_i64 : nil
      if val
        @debug = true
        @write = true
      end
      self
    end

    def arch(val : String?) : self
      @arch = val
      if val
        add_flag("-a")
        add_flag(val)
      end
      self
    end

    def bits(val : Int32?) : self
      @bits = val
      if val
        add_flag("-b")
        add_flag(val.to_s)
      end
      self
    end

    def cpu(val : String?) : self
      @cpu = val
      if val
        eval("asm.cpu", val)
      end
      self
    end

    def eval(key : String, value : String) : self
      cmd = "#{key}=#{value}"
      @eval_commands << cmd
      add_flag("-e")
      add_flag(cmd)
      self
    end

    def gdb_target(host : String = "127.0.0.1", port : Int32 = 1234) : self
      @target = "gdb://#{host}:#{port}"
      debug_mode(true)
      self
    end

    def clone : Options
      Options.new(
        target: @target,
        flags: @flags.dup,
        debug: @debug,
        write: @write,
        r2_path: @r2_path,
        timeout: @timeout,
        attach_pid: @attach_pid,
        source_paths: @source_paths.dup,
        path_mappings: @path_mappings.dup,
        auto_analyze: @auto_analyze,
        log_commands: @log_commands,
        arch: @arch,
        bits: @bits,
        cpu: @cpu,
        eval_commands: @eval_commands.dup
      )
    end
  end
end
