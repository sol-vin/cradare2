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

      def selected? : Bool
        selected == true
      end
    end
  end
end
