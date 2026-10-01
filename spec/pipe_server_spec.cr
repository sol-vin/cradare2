require "./spec_helper"
require "../src/cradare2/plugin/dispatcher"
require "../src/cradare2/plugin/server"

describe Cradare2::Plugin::Server do
  it "runs interactive command loop and exits cleanly on quit" do
    client = SpecFixtures.build_mock_client
    dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

    input_data = "detect\ninfo\nquit\n"
    in_io = IO::Memory.new(input_data)
    out_io = IO::Memory.new

    Cradare2::Plugin::Server.run(dispatcher, in_io: in_io, out_io: out_io)

    output = out_io.to_s
    output.should contain("Target is a Crystal binary!")
    output.should contain("=== Crystal Target Info ===")
  end

  it "stops dispatching when encountering EOF" do
    client = SpecFixtures.build_mock_client
    dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

    in_io = IO::Memory.new("detect\n")
    out_io = IO::Memory.new

    Cradare2::Plugin::Server.run(dispatcher, in_io: in_io, out_io: out_io)
    out_io.to_s.should contain("Target is a Crystal binary!")
  end
end
