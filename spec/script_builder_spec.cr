require "./spec_helper"

describe Cradare2::Util::ScriptBuilder do
  it "generates radare2 .rc script with architectures, flags, formats, and macros" do
    builder = Cradare2::Util::ScriptBuilder.new("PS2 Citrine Script")
    builder.target("game.iso")
    builder.arch("mips")
    builder.cpu("r5900")
    builder.bits(32)
    builder.section("Hardware Segments")
    builder.flag("spram.start", 0x70000000, "16KB Fast Scratchpad")
    builder.flag("gs.pmode", 0x12000000)
    builder.format("gs_pmode", "ww (qword)raw (dword)low (dword)high")
    builder.macro("ps2_spram", "pxw 32 @ 0x70000000")

    output = builder.to_s
    output.should contain("#!/usr/bin/env r2 -i")
    output.should contain("# PS2 Citrine Script")
    output.should contain("o game.iso")
    output.should contain("e asm.arch = mips")
    output.should contain("e asm.cpu = r5900")
    output.should contain("e asm.bits = 32")
    output.should contain("f spram.start = 0x70000000")
    output.should contain("CC 16KB Fast Scratchpad @ 0x70000000")
    output.should contain("f gs.pmode = 0x12000000")
    output.should contain("pf.gs_pmode ww (qword)raw (dword)low (dword)high")
    output.should contain("(ps2_spram; pxw 32 @ 0x70000000)")
  end
end
