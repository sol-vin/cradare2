require "../client"
require "./command"
require "./commands/detect_command"
require "./commands/info_command"
require "./commands/demangle_command"
require "./commands/demangle_all_command"
require "./commands/lines_command"
require "./commands/source_command"
require "./commands/asm_command"
require "./commands/interleaved_command"
require "./commands/classes_command"
require "./commands/methods_command"
require "./commands/inspect_command"
require "./commands/crash_command"
require "./server"

module Cradare2
  module Plugin
    # Extensible command dispatcher implementing the radare2 `crystal` command suite.
    # Uses a command registry pattern supporting custom commands, aliases, and universal JSON (-j) output.
    class CommandDispatcher
      getter client : Client
      getter prefix : String
      getter commands : Hash(String, Command) = Hash(String, Command).new
      getter command_list : Array(Command) = [] of Command

      def initialize(@client : Client, @prefix : String = "crystal")
        register_default_commands if @prefix == "crystal"
      end

      # Registers a command handler with the dispatcher.
      def register(cmd : Command) : self
        @commands[cmd.name.downcase] = cmd
        cmd.aliases.each do |a|
          @commands[a.downcase] = cmd
        end
        @command_list << cmd unless @command_list.includes?(cmd)
        self
      end

      # Dispatches an array of arguments.
      def dispatch(args : Array(String)) : String
        dispatch(args.join(" "))
      end

      # Dispatches a command string and returns the output string.
      def dispatch(cmd_line : String) : String
        raw_args = cmd_line.strip.split(/\s+/)
        return help if raw_args.empty? || raw_args.first.empty?

        # Strip optional command prefix (e.g. "crystal", "godot", "lapis")
        if raw_args.first.downcase == @prefix.downcase
          raw_args.shift
          return help if raw_args.empty?
        end

        # Check for -j / --json flag anywhere in arguments
        json_mode = false
        args = [] of String
        raw_args.each do |arg|
          if arg == "-j" || arg == "--json"
            json_mode = true
          else
            args << arg
          end
        end

        return help if args.empty?

        subcmd = args.shift.downcase

        case subcmd
        when "help", "-h", "--help", "?"
          return help
        end

        # Find command directly or check for trailing 'j' (e.g. "infoj" -> "info" with json_mode=true)
        handler = @commands[subcmd]?
        if handler.nil? && subcmd.ends_with?('j') && subcmd.size > 1
          candidate = subcmd[0...-1]
          if h = @commands[candidate]?
            handler = h
            json_mode = true
          end
        end

        if handler
          handler.execute(@client, args, json: json_mode)
        else
          "Unknown #{@prefix} command: '#{subcmd}'. Type '#{@prefix} help' for available commands."
        end
      rescue ex
        "Error executing '#{cmd_line}': #{ex.message}"
      end

      # Generates the interactive help menu.
      def help : String
        rows = @command_list.map do |cmd|
          aliases_str = cmd.aliases.empty? ? "" : " (#{cmd.aliases.join(", ")})"
          [cmd.name + aliases_str, cmd.summary]
        end
        tbl = Util::CLIFormatter.table(["Command", "Description"], rows, border_style: :rounded)

        String.build do |str|
          str.puts Util::CLIFormatter.rule("Usage: #{@prefix} <command> [args...] [-j]")
          str.puts
          str.puts tbl
          str.puts
          str.puts "Flags:"
          str.puts "  -j, --json                 Output results in JSON format"
        end
      end

      private def register_default_commands : Nil
        register(Commands::DetectCommand.new)
        register(Commands::InfoCommand.new)
        register(Commands::DemangleCommand.new)
        register(Commands::DemangleAllCommand.new)
        register(Commands::LinesCommand.new)
        register(Commands::SourceCommand.new)
        register(Commands::AsmCommand.new)
        register(Commands::InterleavedCommand.new)
        register(Commands::ClassesCommand.new)
        register(Commands::MethodsCommand.new)
        register(Commands::InspectCommand.new)
        register(Commands::CrashCommand.new)
      end
    end
  end
end
