module Cradare2
  # Configuration options for establishing a radare2 session.
  class Options
    property target : String?
    property flags : Array(String)
    property debug : Bool
    property write : Bool
    property r2_path : String?
    property timeout : Time::Span?
    property source_paths : Array(String)
    property path_mappings : Hash(String, String)
    property auto_analyze : Bool
    property log_commands : Bool

    def initialize(
      @target : String? = nil,
      @flags : Array(String) = [] of String,
      @debug : Bool = false,
      @write : Bool = false,
      @r2_path : String? = nil,
      @timeout : Time::Span? = nil,
      @source_paths : Array(String) = [] of String,
      @path_mappings : Hash(String, String) = Hash(String, String).new,
      @auto_analyze : Bool = false,
      @log_commands : Bool = false,
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

    def clone : Options
      Options.new(
        target: @target,
        flags: @flags.dup,
        debug: @debug,
        write: @write,
        r2_path: @r2_path,
        timeout: @timeout,
        source_paths: @source_paths.dup,
        path_mappings: @path_mappings.dup,
        auto_analyze: @auto_analyze,
        log_commands: @log_commands
      )
    end
  end
end
