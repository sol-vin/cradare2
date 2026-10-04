require "./spec_helper"
require "../src/cradare2/ps2/citrine"

describe "PlayStation 2 and Citrine Support" do
  describe Cradare2::Platform::PS2::Registers do
    it "defines correct PS2 hardware memory map and registers" do
      Cradare2::Platform::PS2::Registers::SPRAM_START.should eq(0x70000000_u64)
      Cradare2::Platform::PS2::Registers::SPRAM_END.should eq(0x70004000_u64)
      Cradare2::Platform::PS2::Registers::SPRAM_SIZE.should eq(0x4000_u64)
      Cradare2::Platform::PS2::Registers::DEFAULT_CANARY.should eq(0xDEADBEEF_u32)
      Cradare2::Platform::PS2::Registers::GS_PMODE.should eq(0x12000000_u64)
      Cradare2::Platform::PS2::Registers::DMAC_CHCR2.should eq(0x1000A000_u64)
    end
  end

  describe Cradare2::Platform::PS2::GifDissector do
    it "decodes 128-bit GIFTag" do
      # 16 bytes: NLOOP=10, EOP=1, FLG=0 (PACKED), NREG=1
      # low: 10 | (1 << 15) | (0 << 58) | (1 << 60)
      low = 10_u64 | (1_u64 << 15) | (1_u64 << 60)
      high = 0_u64
      bytes = Bytes.new(16)
      IO::ByteFormat::LittleEndian.encode(low, bytes[0, 8])
      IO::ByteFormat::LittleEndian.encode(high, bytes[8, 8])

      tag = Cradare2::Platform::PS2::GifDissector.decode_giftag(bytes)
      tag.nloop.should eq(10_u32)
      tag.eop.should be_true
      tag.flg.should eq("PACKED")
      tag.nreg.should eq(1_u32)
    end

    it "describes PRIM register" do
      # PRIM: ptype=3 (TRIANGLE), iip=1 (Gouraud), tme=1 (TexOn), abe=1 (BlendOn)
      data = 3_u64 | (1_u64 << 3) | (1_u64 << 4) | (1_u64 << 6)
      desc = Cradare2::Platform::PS2::GifDissector.describe_gs_register(Cradare2::Platform::PS2::Registers::REG_PRIM, data)
      desc.should contain("Type=TRIANGLE")
      desc.should contain("Shading=Gouraud")
      desc.should contain("TexOn")
      desc.should contain("BlendOn")
    end

    it "describes RGBAQ register" do
      # RGBAQ: R=255, G=128, B=64, A=32
      data = 255_u64 | (128_u64 << 8) | (64_u64 << 16) | (32_u64 << 24)
      desc = Cradare2::Platform::PS2::GifDissector.describe_gs_register(Cradare2::Platform::PS2::Registers::REG_RGBAQ, data)
      desc.should contain("R=255")
      desc.should contain("G=128")
      desc.should contain("B=64")
      desc.should contain("A=32")
    end

    it "describes XYZ2 kick vs XYZ3 no kick" do
      # XYZ2: Kick
      desc2 = Cradare2::Platform::PS2::GifDissector.describe_gs_register(Cradare2::Platform::PS2::Registers::REG_XYZ2, 0x10002000_u64)
      desc2.should contain("[DRAW KICK]")

      # XYZ3: No Kick
      desc3 = Cradare2::Platform::PS2::GifDissector.describe_gs_register(Cradare2::Platform::PS2::Registers::REG_XYZ3, 0x10002000_u64)
      desc3.should contain("[NO KICK]")
    end

    it "warns on TEST_1 with always discard setting" do
      # TEST with zte=0, ztst=0 => NEVER all pixels fail!
      data = 0_u64
      desc = Cradare2::Platform::PS2::GifDissector.describe_gs_register(Cradare2::Platform::PS2::Registers::REG_TEST_1, data)
      desc.should contain("NEVER (All pixels fail!)")
      desc.should contain("[!! WARNING: ALWAYS DISCARD !!]")
    end
  end

  describe Cradare2::Platform::PS2::Helper do
    it "configures EE and IOP architectures" do
      executed = [] of String
      mock = Cradare2::Transport::MockTransport.new do |cmd|
        executed << cmd
        ""
      end

      client = Cradare2::Client.new(mock)
      client.ps2.configure_ee
      executed.should contain("e asm.arch = mips; e asm.cpu = r5900; e asm.bits = 32")

      client.citrine.configure_iop
      executed.should contain("e asm.arch = mips; e asm.cpu = mips1; e asm.bits = 32")
    end

    it "verifies SPRAM stack canary" do
      mock = Cradare2::Transport::MockTransport.new do |cmd|
        if cmd.starts_with?("pxj 4 @ 0x70000000")
          # 0xDEADBEEF in LittleEndian: EF BE AD DE
          "[239, 190, 173, 222]"
        else
          "[]"
        end
      end

      client = Cradare2::Client.new(mock)
      client.ps2.verify_canary.should be_true
      client.citrine.verify_canary(0x70000000_u64, 0x12345678_u32).should be_false
    end

    it "generates standalone PS2 script" do
      mock = Cradare2::Transport::MockTransport.new { "" }
      client = Cradare2::Client.new(mock)
      script = client.ps2.generate_script("game.iso")
      script.should contain("e asm.arch = mips")
      script.should contain("e asm.cpu = r5900")
      script.should contain("f spram.start = 0x70000000")
      script.should contain("pf.gs_pmode")
    end
  end
end
