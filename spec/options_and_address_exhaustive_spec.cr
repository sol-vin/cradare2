require "./spec_helper"

describe "Options & Address Resolution Exhaustive Suite" do
  describe Cradare2::AddressUtils do
    it "converts UInt64 to standard hex strings and u64 integers" do
      val = 0x140001000_u64
      Cradare2::AddressUtils.to_hex(val).should eq("0x140001000")
      Cradare2::AddressUtils.to_u64?(val).should eq(val)
      Cradare2::AddressUtils.to_u64(val).should eq(val)
    end

    it "converts positive and zero Int64 and Int32 values" do
      Cradare2::AddressUtils.to_hex(4096_i64).should eq("0x1000")
      Cradare2::AddressUtils.to_u64?(4096_i64).should eq(4096_u64)

      Cradare2::AddressUtils.to_hex(255_i32).should eq("0xff")
      Cradare2::AddressUtils.to_u64?(255_i32).should eq(255_u64)
      Cradare2::AddressUtils.to_u64?(0_i32).should eq(0_u64)
    end

    it "handles negative integers by rejecting or wrapping safely" do
      neg = -1_i64
      Cradare2::AddressUtils.to_u64?(neg).should be_nil
    end

    it "parses hex string addresses with 0x prefix, uppercase 0X, and h suffix" do
      Cradare2::AddressUtils.to_u64?("0x401000").should eq(0x401000_u64)
      Cradare2::AddressUtils.to_u64?("0X401000").should eq(0x401000_u64)
      Cradare2::AddressUtils.to_u64?("401000h").should eq(0x401000_u64)
    end

    it "parses decimal string offsets returned by radare2 seek commands" do
      # 4198400 in decimal == 0x401000
      Cradare2::AddressUtils.to_u64?("4198400").should eq(4198400_u64)
      Cradare2::AddressUtils.to_hex("4198400").should eq("0x401000")
    end

    it "preserves register names and symbol expressions in to_hex unchanged" do
      Cradare2::AddressUtils.to_hex("rip").should eq("rip")
      Cradare2::AddressUtils.to_hex("rax + 8").should eq("rax + 8")
      Cradare2::AddressUtils.to_hex("sym.main").should eq("sym.main")
      Cradare2::AddressUtils.to_u64?("rip").should be_nil
    end

    it "raises ArgumentError when to_u64! fails on unresolvable symbol" do
      expect_raises(ArgumentError, /Cannot parse address/) do
        Cradare2::AddressUtils.to_u64!("unresolvable_symbol_xyz")
      end
    end
  end

  describe Cradare2::Options do
    it "initializes with sensible default configuration" do
      opts = Cradare2::Options.new
      opts.target.should be_nil
      opts.flags.should be_empty
      opts.debug.should be_false
      opts.write.should be_false
      opts.auto_analyze.should be_false
      opts.timeout.should be_nil
      opts.r2_path.should be_nil
    end

    it "supports fluent builder chaining" do
      opts = Cradare2::Options.new
      opts.target("game.dll")
        .debug_mode
        .write_mode
        .skip_analysis
        .timeout(10.seconds)
        .add_flag("-2")
        .add_flags(["-e", "asm.arch=x86"])
        .r2_path("/usr/bin/r2")

      opts.target.should eq("game.dll")
      opts.debug.should be_true
      opts.write.should be_true
      opts.auto_analyze.should be_false
      opts.timeout.should eq(10.seconds)
      opts.flags.should eq(["-2", "-e", "asm.arch=x86"])
      opts.r2_path.should eq("/usr/bin/r2")
    end

    it "allows toggling analysis and write modes back and forth" do
      opts = Cradare2::Options.new
      opts.skip_analysis
      opts.auto_analyze.should be_false
      opts.analyze_on_open
      opts.auto_analyze.should be_true

      opts.write_mode
      opts.write.should be_true
      opts.read_only_mode
      opts.write.should be_false
    end

    it "clones options cleanly" do
      opts1 = Cradare2::Options.new(target: "test.exe", debug: true, flags: ["-e", "asm.bits=64"])
      opts2 = opts1.clone
      opts2.target.should eq("test.exe")
      opts2.debug.should be_true
      opts2.flags.should eq(["-e", "asm.bits=64"])

      # Mutating clone does not mutate original
      opts2.target("other.exe")
      opts1.target.should eq("test.exe")
    end
  end
end
