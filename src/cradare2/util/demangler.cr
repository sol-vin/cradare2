module Cradare2
  module Util
    # Demangler for Crystal, C++, and Rust symbol names.
    module Demangler
      @@cache = Hash(String, String).new

      # Demangles a symbol name. If an optional radare2 command runner is given,
      # it can query radare2's built-in demangler (`?m`) for C++/Rust/MSVC symbols.
      def self.demangle(symbol : String, client : Transport::Base? = nil) : String
        return symbol if symbol.empty?
        if cached = @@cache[symbol]?
          return cached
        end

        demangled = demangle_internal(symbol, client)
        @@cache[symbol] = demangled
        demangled
      end

      # Clears the demangling cache.
      def self.clear_cache : Nil
        @@cache.clear
      end

      private def self.demangle_internal(symbol : String, client : Transport::Base?) : String
        # Check if it's a Crystal mangled symbol
        if is_crystal_symbol?(symbol)
          return clean_crystal_symbol(symbol)
        end

        # If r2 client is available, try radare2's demangler
        if client && is_mangled_native?(symbol)
          begin
            res = client.cmd("?m #{symbol}").strip
            if !res.empty? && res != symbol && !res.includes?("unknown")
              return res
            end
          rescue
          end
        end

        # Fallback to cleaning leading underscores or returning symbol
        symbol
      end

      # Checks if symbol matches common Crystal mangled symbol conventions
      def self.is_crystal_symbol?(symbol : String) : Bool
        symbol.starts_with?('*') ||
          symbol.starts_with?('~') ||
          symbol.includes?("::") ||
          symbol.includes?("#") ||
          symbol.starts_with?("__crystal_")
      end

      # Checks if symbol looks like Itanium (_Z...) or MSVC (?...) mangled C++
      def self.is_mangled_native?(symbol : String) : Bool
        symbol.starts_with?("_Z") ||
          symbol.starts_with?("? ") ||
          symbol.starts_with?("?") ||
          symbol.starts_with?("_R") # Rust v0
      end

      # Cleans Crystal mangled names for human-readable display
      def self.clean_crystal_symbol(symbol : String) : String
        s = symbol
        # Remove radare2 symbol prefixes
        if s.starts_with?("sym.imp.")
          s = s[8..]
        elsif s.starts_with?("sym.")
          s = s[4..]
        end

        # Remove leading '*' or '~' used in Crystal internal symbols
        s = s.lstrip("*~")
        s
      end
    end
  end
end
