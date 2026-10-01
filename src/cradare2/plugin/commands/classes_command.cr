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

          String.build do |str|
            str.puts "Discovered Crystal Classes/Modules (#{classes.size}):"
            classes.each do |c|
              str.puts "  - #{c}"
            end
          end
        end
      end
    end
  end
end
