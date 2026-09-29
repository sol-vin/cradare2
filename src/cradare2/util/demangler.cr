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
        s = symbol
        if s.starts_with?("sym.imp.")
          s = s[8..]
        elsif s.starts_with?("sym.")
          s = s[4..]
        end

        s.starts_with?('*') ||
          s.starts_with?('~') ||
          s.includes?("::") ||
          s.includes?('#') ||
          s.starts_with?("__crystal_")
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

      # Parses a cleaned or mangled Crystal symbol into {class_name, method_name, is_instance_method}
      # Returns nil if the symbol cannot be decomposed into a Crystal class and method.
      def self.parse_crystal_method(symbol : String) : Tuple(String, String, Bool)?
        cleaned = clean_crystal_symbol(symbol)

        # Check for instance method separator '#'
        if hash_idx = cleaned.index('#')
          class_name = cleaned[0...hash_idx]
          method_name = cleaned[(hash_idx + 1)..]
          # Clean inherited marker like Foo@Bar -> Foo
          if at_idx = class_name.index('@')
            class_name = class_name[0...at_idx]
          end
          return {class_name, method_name, true} unless class_name.empty? || method_name.empty?
        end

        # Check for class/module method separator '::'
        # For class methods, find the '::' right before the method name
        # In Crystal, class names start with an uppercase letter, while methods start with lowercase/symbol/_
        parts = cleaned.split("::")
        if parts.size >= 2
          method_idx = parts.index { |p| p[0]?.try(&.ascii_lowercase?) || p.starts_with?('_') || p.starts_with?('[') }
          if method_idx && method_idx > 0
            class_name = parts[0...method_idx].join("::")
            method_name = parts[method_idx..].join("::")
            return {class_name, method_name, false} unless class_name.empty? || method_name.empty?
          else
            last_colon = cleaned.rindex("::")
            if last_colon
              class_name = cleaned[0...last_colon]
              method_name = cleaned[(last_colon + 2)..]
              return {class_name, method_name, false} unless class_name.empty? || method_name.empty?
            end
          end
        end

        nil
      end
    end
  end
end
