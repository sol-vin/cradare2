require "./spec_helper"

describe "MIPS R5900 & IOP CPU Registers" do
  it "exposes named MIPS registers" do
    mips_regs = {
      "zero" => 0_u64,
      "at"   => 0x1_u64,
      "v0"   => 0x10_u64,
      "v1"   => 0x20_u64,
      "a0"   => 0x100_u64,
      "a1"   => 0x200_u64,
      "a2"   => 0x300_u64,
      "a3"   => 0x400_u64,
      "t0"   => 0x1000_u64,
      "t1"   => 0x2000_u64,
      "t2"   => 0x3000_u64,
      "t3"   => 0x4000_u64,
      "t4"   => 0x5000_u64,
      "t5"   => 0x6000_u64,
      "t6"   => 0x7000_u64,
      "t7"   => 0x8000_u64,
      "t8"   => 0x9000_u64,
      "t9"   => 0xA000_u64,
      "s0"   => 0x1111_u64,
      "s1"   => 0x2222_u64,
      "s2"   => 0x3333_u64,
      "s3"   => 0x4444_u64,
      "s4"   => 0x5555_u64,
      "s5"   => 0x6666_u64,
      "s6"   => 0x7777_u64,
      "s7"   => 0x8888_u64,
      "gp"   => 0x00200000_u64,
      "sp"   => 0x001FFF00_u64,
      "fp"   => 0x001FFF50_u64,
      "ra"   => 0x00100450_u64,
      "hi"   => 0x55_u64,
      "lo"   => 0xAA_u64,
      "pc"   => 0x00100400_u64,
    }

    regs = Cradare2::Model::Registers.new(mips_regs)

    regs.zero.should eq(0_u64)
    regs.at.should eq(1_u64)
    regs.v0.should eq(0x10_u64)
    regs.v1.should eq(0x20_u64)
    regs.a0.should eq(0x100_u64)
    regs.a1.should eq(0x200_u64)
    regs.a2.should eq(0x300_u64)
    regs.a3.should eq(0x400_u64)
    regs.t0.should eq(0x1000_u64)
    regs.t9.should eq(0xA000_u64)
    regs.s0.should eq(0x1111_u64)
    regs.s7.should eq(0x8888_u64)
    regs.gp.should eq(0x00200000_u64)
    regs.sp.should eq(0x001FFF00_u64)
    regs.bp.should eq(0x001FFF50_u64)
    regs.ra.should eq(0x00100450_u64)
    regs.hi.should eq(0x55_u64)
    regs.lo.should eq(0xAA_u64)
    regs.pc.should eq(0x00100400_u64)
  end

  it "diffs register state accurately" do
    old_regs = Cradare2::Model::Registers.new({"v0" => 0_u64, "v1" => 5_u64})
    new_regs = Cradare2::Model::Registers.new({"v0" => 10_u64, "v1" => 5_u64})

    diff = new_regs.diff(old_regs)
    diff.has_key?("v0").should be_true
    diff["v0"].should eq({0_u64, 10_u64})
    diff.has_key?("v1").should be_false
  end
end
