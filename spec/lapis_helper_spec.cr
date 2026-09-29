require "./spec_helper"

describe Cradare2::DSL::LapisHelper do
  it "verifies valid GDExtension exports" do
    client = SpecFixtures.build_mock_client
    check = client.lapis.verify_gdextension
    check.valid.should be_true
    check.entrypoint_found.should be_true
    check.entrypoint_name.should eq("lapis_gdextension_entry")
    check.arch.should eq("x86")
    check.bits.should eq(64)
    check.warnings.should be_empty
  end

  it "detects missing GDExtension entrypoint" do
    client = Cradare2.mock
    mock = client.transport.as(Cradare2::Transport::MockTransport)
    mock.on("iEj", "[]") # empty exports
    mock.on("ij", SpecFixtures::SAMPLE_IJ)

    check = client.lapis.verify_gdextension
    check.valid.should be_false
    check.entrypoint_found.should be_false
    check.warnings.should contain("No standard GDExtension entrypoint found (expected one of: lapis_gdextension_entry, godot_gdextension_entry, gdextension_initialize, gdextension_entry)")
  end

  it "filters Crystal symbols" do
    client = SpecFixtures.build_mock_client
    cr_symbols = client.lapis.find_crystal_symbols
    cr_symbols.size.should eq(1)
    cr_symbols[0].name.should eq("sym.*MyGame::Player#_ready:Nil")
  end

  it "discovers Godot bindings imports" do
    client = SpecFixtures.build_mock_client
    bindings = client.lapis.find_godot_bindings
    bindings.size.should eq(2)
    bindings.map(&.name).should eq(["godot_string_new", "godot_variant_call"])
  end

  it "generates crash diagnostic report" do
    client = SpecFixtures.build_mock_client
    mock = client.transport.as(Cradare2::Transport::MockTransport)
    mock.on("fd @ 0x401032", "sym.*MyGame::Player#_process:Float64")

    report = client.lapis.inspect_crash
    report.should contain("Lapis / GDExtension Crash Diagnostic")
    report.should contain("Crash PC (Instruction Pointer): 0x401032")
    report.should contain("Active Function: MyGame::Player#_process:Float64")
    report.should contain("game.dll")
    report.should contain("lapis_gdextension_entry")
    report.should contain("RAX:")
  end
end
