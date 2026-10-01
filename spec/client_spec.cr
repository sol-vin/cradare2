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

  it "finds symbols and functions by name" do
    client = SpecFixtures.build_mock_client
    sym = client.find_symbol("sym.main")
    sym.should_not be_nil
    sym.not_nil!.offset.should eq(4198400)

    fn = client.find_function("sym.main")
    fn.should_not be_nil
    fn.not_nil!.size.should eq(128)

    client.find_symbol("non_existent").should be_nil
    client.find_function("non_existent").should be_nil
  end

  it "filters symbols, functions, exports, imports, and strings with regex and strings" do
    client = SpecFixtures.build_mock_client

    matching_syms = client.symbols_matching(/Player/)
    matching_syms.size.should eq(1)
    matching_syms[0].display_name.should eq("MyGame::Player#_ready:Nil")

    matching_funcs = client.functions_matching("main")
    matching_funcs.size.should eq(1)
    matching_funcs[0].name.should eq("sym.main")

    matching_exports = client.exports_matching(/entry/)
    matching_exports.size.should eq(1)
    matching_exports[0].name.should eq("crystal_library_entry")

    matching_imports = client.imports_matching("string")
    matching_imports.size.should eq(1)
    matching_imports[0].name.should eq("godot_string_new")

    matching_strings = client.strings_matching("Crystal")
    matching_strings.size.should eq(2)
    matching_strings[0].string.should eq("Crystal Library Initialized")
  end

  it "demangles symbols via client" do
    client = Cradare2.mock
    client.demangle("*MyClass#my_method:Int32").should eq("MyClass#my_method:Int32")
  end

  it "executes batch commands" do
    client = SpecFixtures.build_mock_client
    res = client.batch(["s", "s 0x401000"])
    res.size.should eq(2)
    res["s"].should eq("4198400")
  end

  it "records command execution telemetry via on_command hooks" do
    client = SpecFixtures.build_mock_client
    logged_cmds = [] of String
    client.on_command do |cmd, dur, success|
      logged_cmds << cmd
      success.should be_true
      dur.total_milliseconds.should be >= 0
    end

    client.cmd("s")
    logged_cmds.should eq(["s"])
  end

  it "provides top-level delegation shortcuts" do
    client = SpecFixtures.build_mock_client
    client.disassemble(2).size.should eq(2)
    client.read(0x401000_u64, 4).should eq(Bytes[144, 144, 144, 144])
    client.breakpoint(0x401000_u64).should eq(client)
    client.remove_breakpoint(0x401000_u64).should eq(client)
  end

  it "propagates fatal transport errors rather than silently swallowing them" do
    client = SpecFixtures.build_mock_with_handler do |_|
      raise Cradare2::SessionClosedError.new("Session closed")
    end

    expect_raises(Cradare2::SessionClosedError) do
      client.functions
    end

    expect_raises(Cradare2::SessionClosedError) do
      client.symbols
    end
  end
end
