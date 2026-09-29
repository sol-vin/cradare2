require "./spec_helper"

describe Cradare2::Client do
  it "executes raw commands via cmd" do
    client = SpecFixtures.build_mock_client
    client.cmd("s").should eq("4198400")
  end

  it "parses JSON via dynamic cmdj" do
    client = SpecFixtures.build_mock_client
    json = client.cmdj("ij")
    json["bin"]["arch"].as_s.should eq("x86")
    json["bin"]["bits"].as_i.should eq(64)
  end

  it "deserializes strongly typed models via cmdj(cmd, as: T)" do
    client = SpecFixtures.build_mock_client
    info = client.cmdj("ij", as: Cradare2::Model::BinaryInfo)
    info.arch.should eq("x86")
    info.bits.should eq(64)
    info.os.should eq("windows")
    info.pic?.should be_true
  end

  it "seeks and tracks current offset" do
    client = SpecFixtures.build_mock_client
    client.seek(0x401000)
    mock = client.transport.as(Cradare2::Transport::MockTransport)
    mock.history.should contain("s 0x401000")
    client.current_offset.should eq(4198400)
  end

  it "auto-closes client when using Cradare2.mock with a block" do
    closed_client : Cradare2::Client? = nil
    Cradare2.mock do |r2|
      closed_client = r2
      r2.closed?.should be_false
    end
    closed_client.not_nil!.closed?.should be_true
  end

  it "raises ParseError on invalid JSON payload" do
    client = Cradare2.mock
    mock = client.transport.as(Cradare2::Transport::MockTransport)
    mock.on("bad", "not a valid json string {")
    expect_raises(Cradare2::ParseError) do
      client.cmdj("bad")
    end
  end
end
