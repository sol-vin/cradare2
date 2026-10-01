require "./dispatcher"

module Cradare2
  module Plugin
    # Router for mounting multiple command dispatchers or sub-suites under different prefixes.
    # Enables building modular composite plugins (e.g. mounting both "godot" and "lapis" suites)
    # while providing unified command dispatching and help menus.
    class Router
      getter client : Client
      getter routes : Hash(String, CommandDispatcher) = Hash(String, CommandDispatcher).new
      property default_prefix : String? = nil

      def initialize(@client : Client)
      end

      # Mounts a CommandDispatcher under a specific prefix.
      def mount(prefix : String, dispatcher : CommandDispatcher) : self
        clean_prefix = prefix.downcase.strip
        @routes[clean_prefix] = dispatcher
        @default_prefix ||= clean_prefix
        self
      end

      # Mounts and creates a new CommandDispatcher for prefix yielding it to a block.
      def mount(prefix : String, &block : CommandDispatcher -> Nil) : self
        disp = CommandDispatcher.new(@client, prefix: prefix)
        yield disp
        mount(prefix, disp)
      end

      # Dispatches an array of command arguments.
      def dispatch(args : Array(String)) : String
        dispatch(args.join(" "))
      end

      # Dispatches a command string to the appropriate mounted prefix dispatcher.
      def dispatch(cmd_line : String) : String
        trimmed = cmd_line.strip
        return help if trimmed.empty?

        first_token = trimmed.split(/\s+/).first?.try(&.downcase) || ""

        if dispatcher = @routes[first_token]?
          return dispatcher.dispatch(trimmed)
        end

        # Check if first_token is prefixed with colon e.g. "godot:detect"
        @routes.each do |prefix, disp|
          if first_token.starts_with?("#{prefix}:")
            return disp.dispatch(trimmed.sub(/^#{prefix}:/, "#{prefix} "))
          end
        end

        # Check if any dispatcher recognizes the subcommand directly
        @routes.each do |_prefix, disp|
          if disp.commands.has_key?(first_token)
            return disp.dispatch(trimmed)
          end
        end

        # Fallback to default prefix if set
        if (def_p = @default_prefix) && (disp = @routes[def_p]?)
          return disp.dispatch(trimmed)
        end

        help
      end

      # Unified help menu aggregating all mounted command suites.
      def help : String
        String.build do |str|
          str.puts "Available Command Suites:"
          @routes.each do |prefix, disp|
            str.puts "\n=== #{prefix.upcase} COMMANDS (#{prefix} <cmd>) ==="
            disp.command_list.each do |cmd|
              aliases_str = cmd.aliases.empty? ? "" : " (aliases: #{cmd.aliases.join(", ")})"
              str.puts "  #{cmd.name.ljust(16)} #{cmd.summary}#{aliases_str}"
            end
          end
        end
      end
    end
  end
end
