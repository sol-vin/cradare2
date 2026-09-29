require "json"

module Cradare2
  module Model
    # Represents a symbol from `isj` or export from `iEj`.
    struct Symbol
      include JSON::Serializable

      getter name : String = ""
      getter realname : String? = nil
      getter flagname : String? = nil
      getter demangled : String? = nil
      getter type : String? = nil
      getter bind : String? = nil
      getter vaddr : UInt64 = 0_u64
      getter paddr : UInt64? = nil
      getter size : UInt64? = 0_u64
      getter ordinal : Int32? = nil
      getter is_imported : Bool? = nil

      # Returns the most human-readable name available (demangled or realname or name)
      def display_name : String
        demangled || realname || name
      end

      # Virtual address
      def offset : UInt64
        vaddr
      end

      # Check if this symbol is a function
      def function? : Bool
        type == "FUNC" || type == "func"
      end
    end

    # Represents an imported symbol from `iij`.
    struct Import
      include JSON::Serializable

      getter name : String = ""
      getter bind : String? = nil
      getter type : String? = nil
      getter ordinal : Int32? = nil
      getter vaddr : UInt64? = 0_u64
      getter plt : UInt64? = nil

      def offset : UInt64
        vaddr || plt || 0_u64
      end
    end

    # Represents an exported symbol from `iEj`.
    struct Export
      include JSON::Serializable

      getter name : String = ""
      getter flagname : String? = nil
      getter realname : String? = nil
      getter demangled : String? = nil
      getter vaddr : UInt64 = 0_u64
      getter paddr : UInt64? = nil
      getter size : UInt64? = 0_u64
      getter ordinal : Int32? = nil

      def offset : UInt64
        vaddr
      end

      def display_name : String
        demangled || realname || name
      end
    end
  end
end
