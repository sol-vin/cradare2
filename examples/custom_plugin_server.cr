require "../src/cradare2"

# Example custom command for a Godot/Lapis plugin
class GodotClassCountCommand < Cradare2::Plugin::Command
  def initialize
    super(
      name: "count",
      summary: "Report total number of registered Godot classes",
      usage: "godot count",
      aliases: ["cnt"]
    )
  end

  def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
    data = {
      "classes"           => 1240,
      "singletons"        => 48,
      "native_structures" => 36,
    }

    if json
      data.to_json
    else
      "ClassDB Summary: #{data["classes"]} classes, #{data["singletons"]} singletons"
    end
  end
end

target = ARGV.first? || "malloc://1024"
puts "Opening target: #{target}"

Cradare2.open(target) do |r2|
  puts "\n=== Custom Plugin Command Dispatcher ==="

  # 1. Initialize dispatcher with custom prefix 'godot'
  dispatcher = Cradare2::Plugin::CommandDispatcher.new(r2, prefix: "godot")

  # 2. Register custom command
  dispatcher.register(GodotClassCountCommand.new)

  # 3. Dispatch standard command
  puts "Running 'godot count':"
  puts "  #{dispatcher.dispatch("godot count")}"

  # 4. Dispatch with alias
  puts "Running alias 'godot cnt':"
  puts "  #{dispatcher.dispatch("godot cnt")}"

  # 5. Dispatch with JSON output flag
  puts "Running 'godot count -j':"
  puts "  #{dispatcher.dispatch("godot count -j")}"

  # 6. Auto-generated Help
  puts "\nAuto-Generated Help:"
  puts dispatcher.dispatch("godot help")
end
