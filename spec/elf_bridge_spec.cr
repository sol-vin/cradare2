require "./spec_helper"

describe Cradare2::Bridge::ElfBridge do
  it "extracts symbols and batch disassembles functions with telemetry" do
    client = SpecFixtures.build_mock_client
    mock = client.transport.as(Cradare2::Transport::MockTransport)
    mock.on(/^pdj/) { |_cmd| SpecFixtures::SAMPLE_PDJ }

    bridge = client.elf_bridge("citrine_ps2.elf")
    bridge.filter_type = "FUNC"
    symbols = bridge.extract_symbols

    symbols.should_not be_empty
    first_sym = symbols.first
    first_sym.name.should eq("sym.main")
    first_sym.type.should eq("FUNC")

    disasm = bridge.disassemble_symbol(first_sym)
    disasm.symbol.name.should eq("sym.main")
    disasm.instructions.should_not be_empty
    disasm.calls.should contain(4198912_u64)

    results, telemetry = bridge.disassemble_all
    results.should_not be_empty
    telemetry.binary_path.should eq("citrine_ps2.elf")
    telemetry.arch.should eq("x86")
    telemetry.total_symbols.should be > 0
    telemetry.functions_disassembled.should be > 0
  end

  it "supports the declarative Cradare2.elf_bridge DSL" do
    client = SpecFixtures.build_mock_client
    mock = client.transport.as(Cradare2::Transport::MockTransport)
    mock.on(/^pdj/) { |_cmd| SpecFixtures::SAMPLE_PDJ }

    results, telemetry = Cradare2.elf_bridge(client, "app.elf") do |b|
      b.filter_type = "FUNC"
      b.min_size = 0_u64
      b.max_symbols = 10
    end

    results.should_not be_empty
    telemetry.binary_path.should eq("app.elf")
  end
end
