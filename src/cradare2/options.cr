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
  end
end
