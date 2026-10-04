require "./spec_helper"

describe "Cradare2.open_bytes" do
  it "creates an ephemeral binary and yields client with architecture options" do
    # Only run live process test if r2 is available, otherwise verify Mock
    r2_available = Cradare2::Util::Locator.find_r2 rescue nil
    if r2_available
      sample_bytes = Bytes[0x90, 0x90, 0x90, 0xc3] # NOP NOP NOP RET (x86)
      captured_text = ""
      Cradare2.open_bytes(sample_bytes, arch: "x86", bits: 32) do |r2|
        captured_text = r2.disasm_text(2, at: 0)
      end
      captured_text.should_not be_empty
    else
      # Fallback verification: Options creation
      opts = Cradare2::Options.new(arch: "mips", bits: 32, cpu: "r5900")
      opts.arch.should eq("mips")
      opts.bits.should eq(32)
      opts.cpu.should eq("r5900")
    end
  end
end
