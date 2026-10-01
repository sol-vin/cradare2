require "json"

module Cradare2
  module Model
    # Represents process info returned by radare2 `dplj` (attachable/running processes).
    struct ProcessInfo
      include JSON::Serializable

      getter pid : Int32
      getter ppid : Int32? = nil
      getter uid : Int32? = nil
      getter status : String? = nil
      getter path : String? = nil
      getter current : Bool? = nil

      def initialize(
        @pid : Int32,
        @ppid : Int32? = nil,
        @uid : Int32? = nil,
        @status : String? = nil,
        @path : String? = nil,
        @current : Bool? = nil,
      )
      end

      # Returns true if this process is the currently attached process in radare2.
      def current? : Bool
        current == true
      end

      # Returns the base executable filename extracted from the path.
      def name : String
        return "unknown" unless p = @path
        p.gsub('\\', '/').split('/').reject(&.empty?).last? || p
      end

      def to_s(io : IO) : Nil
        io << "PID #{@pid}: #{name}"
        io << " (#{@path})" if @path
      end
    end
  end
end
