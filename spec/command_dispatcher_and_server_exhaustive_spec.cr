require "./spec_helper"

class TestEchoCommand < Cradare2::Plugin::Command
  def initialize
    super(
      name: "echo",
      summary: "Echo back arguments",
      usage: "test echo <text>",
      aliases: ["ec", "print"]
    )
  end

  def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
    if json
      {"args" => args, "count" => args.size}.to_json
    else
      "ECHO: #{args.join(" ")}"
    end
  end
end

class TestFailCommand < Cradare2::Plugin::Command
  def initialize
    super(
      name: "fail",
      summary: "Command that intentionally raises an error",
      usage: "test fail"
    )
  end

  def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
    raise Cradare2::CommandError.new("Simulated command failure")
  end
end

describe "Command Dispatcher & Server Exhaustive Suite" do
  describe Cradare2::Plugin::CommandDispatcher do
    it "initializes with default 'crystal' prefix and default commands" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)
      dispatcher.prefix.should eq("crystal")
      dispatcher.commands.has_key?("info").should be_true
      dispatcher.commands.has_key?("detect").should be_true
    end

    it "initializes with custom prefix e.g. 'godot' or 'lapis' without default crystal commands" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "godot")
      dispatcher.prefix.should eq("godot")
      dispatcher.commands.has_key?("detect").should be_false
    end

    it "dispatches commands using custom prefix" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "godot")
      dispatcher.register(TestEchoCommand.new)

      res = dispatcher.dispatch("godot echo hello world")
      res.should eq("ECHO: hello world")
    end

    it "matches custom prefix case-insensitively" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "godot")
      dispatcher.register(TestEchoCommand.new)

      res = dispatcher.dispatch("GoDoT echo test")
      res.should eq("ECHO: test")
    end

    it "dispatches commands when prefix is omitted" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "godot")
      dispatcher.register(TestEchoCommand.new)

      res = dispatcher.dispatch("echo direct invocation")
      res.should eq("ECHO: direct invocation")
    end

    it "dispatches command aliases" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "test")
      dispatcher.register(TestEchoCommand.new)

      dispatcher.dispatch("test ec short alias").should eq("ECHO: short alias")
      dispatcher.dispatch("test print second alias").should eq("ECHO: second alias")
    end

    it "handles universal -j and --json flags" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "test")
      dispatcher.register(TestEchoCommand.new)

      json1 = dispatcher.dispatch("test echo foo bar -j")
      json1.should eq(%({"args":["foo","bar"],"count":2}))

      json2 = dispatcher.dispatch("test echo baz --json")
      json2.should eq(%({"args":["baz"],"count":1}))
    end

    it "returns help text on empty or whitespace command line" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "test")
      dispatcher.register(TestEchoCommand.new)

      dispatcher.dispatch("").should contain("Usage: test <command>")
      dispatcher.dispatch("   \n\t  ").should contain("Usage: test <command>")
      dispatcher.dispatch("test").should contain("Usage: test <command>")
    end

    it "returns error string on unknown command" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "test")
      dispatcher.register(TestEchoCommand.new)

      res = dispatcher.dispatch("test non_existent_cmd")
      res.should contain("Unknown test command: 'non_existent_cmd'")
      res.should contain("test help")
    end

    it "formats auto-generated help listing all commands and flags" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "mytool")
      dispatcher.register(TestEchoCommand.new)

      help = dispatcher.help
      help.should contain("Usage: mytool <command> [args...] [-j]")
      help.should contain("echo")
      help.should contain("Echo back arguments")
      help.should contain("-j, --json")
    end
  end

  describe Cradare2::Plugin::Server do
    it "reads commands from input IO and writes responses to output IO" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "test")
      dispatcher.register(TestEchoCommand.new)

      input = IO::Memory.new("test echo hello\ntest echo world -j\n")
      output = IO::Memory.new

      Cradare2::Plugin::Server.run(dispatcher, in_io: input, out_io: output)

      output.to_s.should eq("ECHO: hello\n{\"args\":[\"world\"],\"count\":1}\n")
    end

    it "ignores blank lines and continues processing subsequent lines" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "test")
      dispatcher.register(TestEchoCommand.new)

      input = IO::Memory.new("\n\n   \ntest echo valid\n\n")
      output = IO::Memory.new

      Cradare2::Plugin::Server.run(dispatcher, in_io: input, out_io: output)

      output.to_s.should eq("ECHO: valid\n")
    end

    it "catches command errors and outputs error message without terminating server" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "test")
      dispatcher.register(TestFailCommand.new)
      dispatcher.register(TestEchoCommand.new)

      input = IO::Memory.new("test fail\ntest echo recovered\n")
      output = IO::Memory.new

      Cradare2::Plugin::Server.run(dispatcher, in_io: input, out_io: output)

      output_str = output.to_s
      output_str.should contain("Simulated command failure")
      output_str.should contain("ECHO: recovered")
    end

    it "exits server loop cleanly when input stream reaches EOF" do
      client = Cradare2.mock
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "test")

      empty_input = IO::Memory.new("")
      output = IO::Memory.new

      # Should return immediately on EOF without hanging
      Cradare2::Plugin::Server.run(dispatcher, in_io: empty_input, out_io: output)
      output.to_s.should be_empty
    end
  end
end
