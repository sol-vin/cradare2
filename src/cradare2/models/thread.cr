require "json"

module Cradare2
  module Model
    # Represents a thread in a debugged process from radare2 `dptj`.
    struct Thread
      include JSON::Serializable

      getter id : Int32 = 0
      getter status : String? = nil
      getter selected : Bool? = nil
      getter name : String? = nil

      def initialize(
        @id : Int32 = 0,
        @status : String? = nil,
        @selected : Bool? = nil,
        @name : String? = nil,
      )
      end

      def selected? : Bool
        selected == true
      end

      def running? : Bool
        @status.try(&.downcase.starts_with?("r")) == true
      end

      def stopped? : Bool
        @status.try(&.downcase.starts_with?("s")) == true
      end
    end
  end
end
