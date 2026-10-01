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

          "Demangled and renamed #{results.size} functions/symbols in radare2 session."
        end
      end
    end
  end
end
