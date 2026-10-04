require "./locator"
require "./cli_formatter"

module Cradare2
  module Util
    # Diagnostic tool to inspect radare2 environment, plugins, symbolizers, and architecture support.
    class Doctor
      record CheckItem, name : String, status : Symbol, detail : String, tip : String? = nil

      getter items : Array(CheckItem) = [] of CheckItem

      def run : self
        @items.clear

        # 1. radare2 binary
        r2_bin = Util::Locator.find_r2 rescue nil
        if r2_bin && File.file?(r2_bin)
          @items << CheckItem.new("radare2 Executable", :pass, r2_bin)

          # 2. radare2 version
          version_io = IO::Memory.new
          Process.run(r2_bin, ["-v"], output: version_io, error: version_io) rescue nil
          version_out = version_io.to_s.strip
          first_line = version_out.lines.first?.try(&.strip) || "Unknown version"
          if first_line.includes?("radare2")
            @items << CheckItem.new("radare2 Version", :pass, first_line)
          else
            @items << CheckItem.new(
              "radare2 Version",
              :warn,
              "Could not determine version: #{first_line}",
              "Ensure radare2 is installed properly via scoop, brew, or apt."
            )
          end

          # 3. Architecture support (MIPS, ARM, x86)
          arch_io = IO::Memory.new
          Process.run(r2_bin, ["-e", "asm.arch=?"], output: arch_io, error: arch_io) rescue nil
          arch_out = arch_io.to_s.strip
          has_mips = arch_out.includes?("mips")
          has_arm = arch_out.includes?("arm")
          has_x86 = arch_out.includes?("x86")

          arch_summary = "x86: #{has_x86 ? "OK" : "MISSING"}, ARM: #{has_arm ? "OK" : "MISSING"}, MIPS (PS2): #{has_mips ? "OK" : "MISSING"}"
          if has_mips && has_x86
            @items << CheckItem.new("Target Architectures", :pass, arch_summary)
          else
            @items << CheckItem.new(
              "Target Architectures",
              :warn,
              arch_summary,
              "Some architectures may require reinstalling radare2 with full plugins enabled."
            )
          end
        else
          @items << CheckItem.new(
            "radare2 Executable",
            :fail,
            "radare2 executable not found in PATH or standard install locations",
            "Install radare2 via Scoop ('scoop install radare2'), Homebrew ('brew install radare2'), or Choco."
          )
        end

        # 4. llvm-symbolizer (for source line resolution)
        llvm_sym = Process.find_executable("llvm-symbolizer")
        if llvm_sym
          @items << CheckItem.new("llvm-symbolizer", :pass, llvm_sym)
        else
          @items << CheckItem.new(
            "llvm-symbolizer",
            :info,
            "llvm-symbolizer not found in PATH (optional)",
            "Installing LLVM enables high-throughput DWARF/PDB source line resolution for Crystal binaries."
          )
        end

        # 5. Crystal compiler
        crystal_bin = Process.find_executable("crystal")
        if crystal_bin
          c_io = IO::Memory.new
          Process.run(crystal_bin, ["--version"], output: c_io, error: c_io) rescue nil
          c_ver = c_io.to_s.lines.first?.try(&.strip) || "Crystal installed"
          @items << CheckItem.new("Crystal Compiler", :pass, "#{crystal_bin} (#{c_ver})")
        else
          @items << CheckItem.new(
            "Crystal Compiler",
            :warn,
            "Crystal compiler not found in PATH",
            "Install Crystal from https://crystal-lang.org/install/."
          )
        end

        self
      end

      # Renders a formatted terminal report.
      def render : String
        io = IO::Memory.new
        io.puts CLIFormatter.badge("cradare2", bg: :cyan) + " Environment & Toolchain Diagnostics"
        io.puts "=" * 60

        @items.each do |item|
          badge = case item.status
                  when :pass then CLIFormatter.badge("PASS", bg: :green)
                  when :warn then CLIFormatter.badge("WARN", bg: :yellow)
                  when :fail then CLIFormatter.badge("FAIL", bg: :red)
                  else            CLIFormatter.badge("INFO", bg: :blue)
                  end
          io.puts "#{badge} #{item.name}: #{item.detail}"
          if tip = item.tip
            io.puts "       Tip: #{tip}"
          end
        end

        io.puts "=" * 60
        has_fail = @items.any? { |i| i.status == :fail }
        if has_fail
          io.puts CLIFormatter.badge("STATUS", bg: :red) + " One or more required components are missing."
        else
          io.puts CLIFormatter.badge("STATUS", bg: :green) + " All required toolchain components are operational."
        end

        io.to_s
      end
    end
  end
end
