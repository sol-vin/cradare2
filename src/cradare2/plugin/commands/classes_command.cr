require "../command"

module Cradare2
  module Plugin
    module Commands
      class ClassesCommand < Command
        def initialize
          super("classes", "List all detected Crystal classes/modules", "crystal classes")
        end

        def execute(client : Client, args : Array(String), json : Bool = false) : String
          classes = client.crystal.classes

          if json
            return {
              "count"   => classes.size,
              "classes" => classes,
            }.to_json
          end

          return "No Crystal classes found." if classes.empty?

          rows = classes.map_with_index(1) do |c, idx|
            [idx.to_s, c]
          end
          tbl = Util::CLIFormatter.table(["#", "Class / Module Name"], rows, border_style: :rounded)

          String.build do |str|
            str.puts Util::CLIFormatter.rule("Discovered Crystal Classes/Modules (#{classes.size}):")
            str.puts
            str.puts tbl
          end
        end
      end
    end
  end
end
