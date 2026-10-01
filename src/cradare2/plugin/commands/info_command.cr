require "../command"

module Cradare2
  module Plugin
    module Commands
      class InfoCommand < Command
        def initialize
          super("info", "Display Crystal runtime & binary metadata", "crystal info")
        end

        def execute(client : Client, args : Array(String), json : Bool = false) : String
          is_cr = client.crystal.crystal_binary?
          ep = client.crystal.entrypoint
          gc_funcs = client.crystal.gc_functions
          classes = client.crystal.classes

          if json
            return {
              "crystal_binary" => is_cr,
              "entrypoint"     => ep,
              "gc_functions"   => gc_funcs.size,
              "classes_count"  => classes.size,
              "classes"        => classes,
            }.to_json
          end

          rows = [
            ["Crystal Binary: #{is_cr ? "Yes" : "No"}"],
          ]
          if ep
            rows << ["Entrypoint (__crystal_main): 0x#{ep.to_s(16)}"]
          end
          rows << ["Boehm GC Functions: #{gc_funcs.size} found"]
          rows << ["Crystal Classes/Modules: #{classes.size} discovered"]

          Util::CLIFormatter.table(["=== Crystal Target Info ==="], rows, border_style: :rounded)
        end
      end
    end
  end
end
