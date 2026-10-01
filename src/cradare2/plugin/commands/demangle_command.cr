require "../command"

module Cradare2
  module Plugin
    module Commands
      class DemangleCommand < Command
        def initialize
          super("demangle", "Demangle a single Crystal/PDB symbol", "crystal demangle <symbol>")
        end

        def execute(client : Client, args : Array(String), json : Bool = false) : String
          if args.empty?
            return json ? {"error" => "Usage: crystal demangle <symbol>"}.to_json : "Usage: crystal demangle <symbol>"
          end

          sym = args.join(" ")
          demangled = client.crystal.demangle_symbol(sym)

          if json
            return {
              "symbol"    => sym,
              "demangled" => demangled,
            }.to_json
          end

          "#{sym} -> #{demangled}"
        end
      end
    end
  end
end
