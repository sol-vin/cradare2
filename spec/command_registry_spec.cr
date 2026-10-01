require "./spec_helper"
require "../src/cradare2/plugin/dispatcher"
require "../src/cradare2/plugin/command"

# Custom test command
class CustomPingCommand < Cradare2::Plugin::Command
  def initialize
    super("ping", "Responds with pong", "crystal ping", aliases: ["p"])
  end

  def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
    json ? {"message" => "pong"}.to_json : "pong"
  end
end

describe Cradare2::Plugin::CommandDispatcher do
  it "allows registering custom commands and aliases" do
    client = SpecFixtures.build_mock_client
    dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

    dispatcher.register(CustomPingCommand.new)

    dispatcher.dispatch("ping").should eq("pong")
    dispatcher.dispatch("p").should eq("pong")
    dispatcher.dispatch("ping -j").should eq(%({"message":"pong"}))
  end

  it "supports universal -j flag on built-in commands" do
    client = SpecFixtures.build_mock_client
    dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

    # detect -j
    res = dispatcher.dispatch("detect -j")
    json = JSON.parse(res)
    json["crystal"].as_bool.should be_true

    # info -j
    info_res = dispatcher.dispatch("info -j")
    info_json = JSON.parse(info_res)
    info_json["crystal_binary"].as_bool.should be_true
    info_json["classes_count"].as_i.should be >= 0

    # demangle -j
    dem_res = dispatcher.dispatch("demangle sym.*Player#ready:Nil -j")
    dem_json = JSON.parse(dem_res)
    dem_json["demangled"].as_s.should eq("Player#ready:Nil")

    # classes -j
    cls_res = dispatcher.dispatch("classes -j")
    cls_json = JSON.parse(cls_res)
    cls_json["classes"].as_a.should be_a(Array(JSON::Any))
  end

  it "supports configurable command prefixes like godot and lapis" do
    client = SpecFixtures.build_mock_client
    godot_dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "godot")
    godot_dispatcher.register(CustomPingCommand.new)

    godot_dispatcher.prefix.should eq("godot")
    godot_dispatcher.dispatch("godot ping").should eq("pong")
    godot_dispatcher.dispatch("godot p").should eq("pong")
    godot_dispatcher.dispatch("godot ping -j").should eq(%({"message":"pong"}))
    godot_dispatcher.help.should contain("Usage: godot <command>")
  end
end
