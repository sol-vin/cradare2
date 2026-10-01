require "../command"

module Cradare2
  module Plugin
    module Commands
      class SourceCommand < Command
        def initialize
          super("src", "Show source code context for instruction address", "crystal src <addr>", aliases: ["source"])
        end

        def execute(client : Client, args : Array(String), json : Bool = false) : String
          if args.empty?
            return json ? {"error" => "Usage: crystal src <addr>"}.to_json : "Usage: crystal src <addr>"
          end

          addr = parse_address(args.first)
          unless addr
            return json ? {"error" => "Invalid address: #{args.first}"}.to_json : "Invalid address: #{args.first}"
          end

          loc = client.crystal.lines.at(addr)
          unless loc
            return json ? {"error" => "No source mapping found for address 0x#{addr.to_s(16)}"}.to_json : "No source mapping found for address 0x#{addr.to_s(16)}."
          end

          context = client.crystal.lines.reader.read_context(loc.file, loc.line, before: 3, after: 3)
          if context.empty?
            return json ? {"error" => "Source file not accessible: #{loc.file}"}.to_json : "Source file not accessible: #{loc.file}"
          end

          if json
            return {
              "address" => "0x#{addr.to_s(16)}",
              "file"    => loc.file,
              "line"    => loc.line,
              "context" => context.map { |c| {"line" => c[:line], "text" => c[:text], "current" => c[:current]} },
            }.to_json
          end

          String.build do |str|
            str.puts Util::CLIFormatter.rule("=== #{loc.file}:#{loc.line} (0x#{addr.to_s(16)}) ===")
            str.puts
            context.each do |c|
              prefix = c[:current] ? "▶ " : "  "
              str.puts "#{prefix}#{c[:line].to_s.rjust(5)}: #{c[:text]}"
            end
          end
        end
      end
    end
  end
end
