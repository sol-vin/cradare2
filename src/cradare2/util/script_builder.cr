require "../address"

module Cradare2
  module Util
    # Fluent generator for radare2 configuration (.rc) scripts and command macros.
    class ScriptBuilder
      @lines = [] of String

      def initialize(header : String = "Auto-generated radare2 script")
        @lines << "#!/usr/bin/env r2 -i"
        @lines << "# #{header}"
      end

      def target(path : String) : self
        @lines << "o #{path}" unless path.empty?
        self
      end

      def arch(name : String) : self
        @lines << "e asm.arch = #{name}"
        self
      end

      def cpu(name : String) : self
        @lines << "e asm.cpu = #{name}"
        self
      end

      def bits(val : Int32) : self
        @lines << "e asm.bits = #{val}"
        self
      end

      def eval(key : String, value : String) : self
        @lines << "e #{key} = #{value}"
        self
      end

      def section(title : String) : self
        @lines << "\n# --- #{title} ---"
        self
      end

      def comment(text : String) : self
        @lines << "# #{text}"
        self
      end

      def flag(name : String, address : Address, comment : String? = nil) : self
        addr_str = AddressUtils.to_hex(address)
        @lines << "f #{name} = #{addr_str}"
        if comment
          @lines << "CC #{comment} @ #{addr_str}"
        end
        self
      end

      def format(name : String, fmt_string : String) : self
        clean_name = name.starts_with?("pf.") ? name : "pf.#{name}"
        @lines << "#{clean_name} #{fmt_string}"
        self
      end

      def macro(name : String, body : String) : self
        clean_body = body.strip.lstrip('(').rstrip(')')
        @lines << "(#{name}; #{clean_body})"
        self
      end

      def command(raw_cmd : String) : self
        @lines << raw_cmd
        self
      end

      def to_s(io : IO) : Nil
        io.puts @lines.join("\n")
      end

      def to_s : String
        @lines.join("\n") + "\n"
      end

      def save(path : String) : Nil
        File.write(path, to_s)
      end
    end
  end
end
