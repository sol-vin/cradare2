require "../command"

module Cradare2
  module Plugin
    module Commands
      class DemangleAllCommand < Command
        def initialize
          super("demangle-all", "Demangle and rename all functions/flags in session", "crystal demangle-all", aliases: ["demangle_all"])
        end

        def execute(client : Client, args : Array(String), json : Bool = false) : String
          results = client.crystal.demangle_all(apply_to_r2: true)

          if json
            formatted = results.transform_keys { |k| "0x#{k.to_s(16)}" }
            return {
              "demangled_count" => results.size,
              "renamed"         => formatted,
            }.to_json
          end

          badge = Util::CLIFormatter.badge("RENAMED", bg: :green)
          if results.empty?
            "#{badge} No mangled Crystal symbols found to rename."
          else
            rows = results.map do |addr, demangled|
              ["0x#{addr.to_s(16)}", demangled]
            end
            tbl = Util::CLIFormatter.table(["Address", "Demangled Symbol"], rows, border_style: :rounded)
            String.build do |str|
              str.puts "#{badge} Demangled and renamed #{results.size} functions/symbols in radare2 session."
              str.puts
              str.puts tbl
            end
          end
        end
      end
    end
  end
end
