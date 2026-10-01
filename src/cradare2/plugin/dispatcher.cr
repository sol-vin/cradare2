require "../client"
require "../lines/line_helper"
require "../util/demangler"

module Cradare2
  module Plugin
    # Command dispatcher implementing the radare2 `crystal` command suite.
    # Can be run inside radare2 via `#!pipe` or standalone against any binary.
    class CommandDispatcher
      getter client : Client

      def initialize(@client : Client)
      end

      # Dispatches an array of arguments.
      def dispatch(args : Array(String)) : String
        dispatch(args.join(" "))
      end

      # Dispatches a command string and returns the output string.
      def dispatch(cmd_line : String) : String
        args = cmd_line.strip.split(/\s+/)
        return help if args.empty? || args.first.empty?

        subcmd = args.shift.downcase
        # Strip optional "crystal" prefix if user entered "crystal lines ..."
        if subcmd == "crystal"
          return help if args.empty?
          subcmd = args.shift.downcase
        end

        case subcmd
        when "help", "-h", "--help", "?"
          help
        when "detect"
          cmd_detect
        when "info"
          cmd_info
        when "demangle"
          cmd_demangle(args)
        when "demangle-all", "demangle_all"
          cmd_demangle_all
        when "lines"
          cmd_lines(args)
        when "src", "source"
          cmd_src(args)
        when "asm"
          cmd_asm(args)
        when "interleaved", "il"
          cmd_interleaved(args)
        when "classes"
          cmd_classes
        when "methods"
          cmd_methods(args)
        when "inspect"
          cmd_inspect(args)
        when "crash"
          @client.crystal.crash_report
        else
          "Unknown crystal command: '#{subcmd}'. Type 'crystal help' for available commands."
        end
      rescue ex
        "Error executing '#{cmd_line}': #{ex.message}"
      end

      def help : String
        <<-HELP
        Usage: crystal <command> [args...] - radare2 Crystal Plugin

        Commands:
          help                       Show this help menu
          detect                     Check if target is a Crystal binary
          info                       Display Crystal runtime & binary metadata
          demangle <symbol>          Demangle a single Crystal/PDB symbol
          demangle-all               Demangle and rename all functions/flags in session
          lines [addr|func]          Show source-line-to-asm mappings
          lines sync                 Synchronize line table (CL) & comments (CC) to r2
          src <addr>                 Show source code context for instruction address
          asm <file:line>            Show machine instructions for a source line
          interleaved <func>         Show interleaved source and assembly view
          classes                    List all detected Crystal classes/modules
          methods <class>            List all methods for a given class
          inspect string <addr>      Inspect Crystal String memory layout at address
          inspect array <addr>       Inspect Crystal Array(T) header at address
          inspect slice <addr>       Inspect Crystal Slice(T) header at address
          crash                      Generate full demangled crash/debug report
        HELP
      end

      private def cmd_detect : String
        is_cr = @client.crystal.crystal_binary?
        if is_cr
          ep = @client.crystal.entrypoint
          ep_str = ep ? "0x#{ep.to_s(16)}" : "unknown"
          "Target is a Crystal binary! (Entrypoint: #{ep_str})"
        else
          "Target does NOT appear to be a Crystal binary."
        end
      end

      private def cmd_info : String
        String.build do |str|
          str.puts "=== Crystal Target Info ==="
          str.puts "Crystal Binary: #{@client.crystal.crystal_binary? ? "Yes" : "No"}"
          if ep = @client.crystal.entrypoint
            str.puts "Entrypoint (__crystal_main): 0x#{ep.to_s(16)}"
          end
          gc_funcs = @client.crystal.gc_functions
          str.puts "Boehm GC Functions: #{gc_funcs.size} found"
          classes = @client.crystal.classes
          str.puts "Crystal Classes/Modules: #{classes.size} discovered"
        end
      end

      private def cmd_demangle(args : Array(String)) : String
        if args.empty?
          return "Usage: crystal demangle <symbol>"
        end
        sym = args.join(" ")
        demangled = @client.crystal.demangle_symbol(sym)
        "#{sym} -> #{demangled}"
      end

      private def cmd_demangle_all : String
        results = @client.crystal.demangle_all(apply_to_r2: true)
        "Demangled and renamed #{results.size} functions/symbols in radare2 session."
      end

      private def cmd_lines(args : Array(String)) : String
        if args.first? == "sync"
          count = @client.crystal.lines.sync_to_r2(annotate_comments: true)
          return "Synchronized #{count} source line mappings into radare2 (CL table and CC comments)."
        end

        if args.empty?
          # Show summary of all mapped lines
          map = @client.crystal.lines.map
          if map.empty?
            @client.crystal.lines.resolve_all
          end
          files = map.files
          if files.empty?
            return "No source line mappings found. Ensure binary has debug info (PDB or DWARF)."
          end

          String.build do |str|
            str.puts "Mapped Source Files (#{files.size}):"
            files.each do |f|
              lines = map.lines_for_file(f)
              str.puts "  - #{f} (#{lines.size} mapped lines)"
            end
            str.puts "\nUse 'crystal lines <addr|func>' or 'crystal interleaved <func>' to inspect."
          end
        else
          target = args.first
          addr = parse_address(target)
          if addr
            loc = @client.crystal.lines.at(addr)
            if loc
              src = loc.source_code || "(source line unavailable)"
              "0x#{addr.to_s(16)} -> #{loc}\n  | #{src.strip}"
            else
              "No source mapping found for address 0x#{addr.to_s(16)}."
            end
          else
            # Treat as function name
            @client.crystal.lines.interleaved(target)
          end
        end
      end

      private def cmd_src(args : Array(String)) : String
        if args.empty?
          return "Usage: crystal src <addr>"
        end
        addr = parse_address(args.first)
        return "Invalid address: #{args.first}" unless addr

        loc = @client.crystal.lines.at(addr)
        return "No source mapping found for address 0x#{addr.to_s(16)}." unless loc

        context = @client.crystal.lines.reader.read_context(loc.file, loc.line, before: 3, after: 3)
        return "Source file not accessible: #{loc.file}" if context.empty?

        String.build do |str|
          str.puts "=== #{loc.file}:#{loc.line} (0x#{addr.to_s(16)}) ==="
          context.each do |c|
            prefix = c[:current] ? "▶ " : "  "
            str.puts "#{prefix}#{c[:line].to_s.rjust(5)}: #{c[:text]}"
          end
        end
      end

      private def cmd_asm(args : Array(String)) : String
        if args.empty?
          return "Usage: crystal asm <file:line>"
        end
        spec = args.first
        parts = spec.split(':')
        if parts.size < 2
          return "Invalid format. Expected <file:line> (e.g. main.cr:12)"
        end

        line = parts.last.to_i?
        file = parts[0...(parts.size - 1)].join(':')
        return "Invalid line number: #{parts.last}" unless line

        instructions = @client.crystal.lines.for_line(file, line)
        if instructions.empty?
          return "No instructions found for #{file}:#{line}."
        end

        String.build do |str|
          str.puts "Instructions for #{file}:#{line} (#{instructions.size} insts):"
          instructions.each do |ins|
            bytes_str = ins.bytes.empty? ? "" : ins.bytes.ljust(16)
            str.puts "  0x#{ins.address.to_s(16).rjust(8, '0')}  #{bytes_str}  #{ins.opcode}"
          end
        end
      end

      private def cmd_interleaved(args : Array(String)) : String
        if args.empty?
          return "Usage: crystal interleaved <func_name_or_addr>"
        end
        target = args.first
        addr = parse_address(target)
        if addr
          @client.crystal.lines.interleaved(addr)
        else
          @client.crystal.lines.interleaved(target)
        end
      end

      private def cmd_classes : String
        classes = @client.crystal.classes
        return "No Crystal classes found." if classes.empty?

        String.build do |str|
          str.puts "Discovered Crystal Classes/Modules (#{classes.size}):"
          classes.each do |c|
            str.puts "  - #{c}"
          end
        end
      end

      private def cmd_methods(args : Array(String)) : String
        if args.empty?
          return "Usage: crystal methods <class_name>"
        end
        cls = args.first
        methods = @client.crystal.methods_for_class(cls)
        if methods.empty?
          syms = @client.crystal.symbols_for_class(cls)
          return "No methods found for class '#{cls}'." if syms.empty?

          return String.build do |str|
            str.puts "Methods for #{cls} (#{syms.size}):"
            syms.each do |s|
              demangled = Util::Demangler.demangle(s.name, @client.transport)
              str.puts "  0x#{s.vaddr.to_s(16)}: #{demangled} (#{s.size} bytes)"
            end
          end
        end

        String.build do |str|
          str.puts "Methods for #{cls} (#{methods.size}):"
          methods.each do |m|
            demangled = Util::Demangler.demangle(m.name, @client.transport)
            str.puts "  0x#{m.offset.to_s(16)}: #{demangled} (#{m.size} bytes)"
          end
        end
      end

      private def cmd_inspect(args : Array(String)) : String
        if args.size < 2
          return "Usage: crystal inspect <string|array|slice> <address>"
        end
        type = args[0].downcase
        addr = parse_address(args[1])
        return "Invalid address: #{args[1]}" unless addr

        case type
        when "string", "str"
          s = @client.crystal.read_string(addr)
          "Crystal String @ 0x#{addr.to_s(16)}:\n  type_id:  #{s.type_id}\n  bytesize: #{s.bytesize}\n  length:   #{s.length}\n  value:    \"#{s.value}\""
        when "array", "arr"
          arr = @client.crystal.read_array_header(addr)
          "Crystal Array(T) @ 0x#{addr.to_s(16)}:\n  type_id:  #{arr.type_id}\n  size:     #{arr.size}\n  capacity: #{arr.capacity}\n  buffer:   0x#{arr.buffer_address.to_s(16)}"
        when "slice"
          sl = @client.crystal.read_slice_header(addr)
          "Crystal Slice(T) @ 0x#{addr.to_s(16)}:\n  size:      #{sl.size}\n  read_only: #{sl.read_only}\n  pointer:   0x#{sl.pointer_address.to_s(16)}"
        else
          "Unknown inspect type '#{type}'. Supported: string, array, slice."
        end
      end

      private def parse_address(str : String) : UInt64?
        s = str.strip
        if s.starts_with?("0x") || s.starts_with?("0X")
          s[2..].to_u64?(16)
        else
          s.to_u64?(16) || s.to_u64?
        end
      end
    end
  end
end
