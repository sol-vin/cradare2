require "./spec_helper"

describe Cradare2::AddressUtils do
  describe ".to_hex" do
    it "formats integers to 0x-prefixed hex strings" do
      Cradare2::AddressUtils.to_hex(0x140001000_u64).should eq("0x140001000")
      Cradare2::AddressUtils.to_hex(4198400).should eq("0x401000")
      Cradare2::AddressUtils.to_hex(0_u64).should eq("0x0")
    end

    it "preserves strings and symbol names" do
      Cradare2::AddressUtils.to_hex("sym.main").should eq("sym.main")
      Cradare2::AddressUtils.to_hex("0x401000").should eq("0x401000")
    end
  end

  describe ".to_u64?" do
    it "converts unsigned integers" do
      Cradare2::AddressUtils.to_u64?(0x140001000_u64).should eq(0x140001000_u64)
    end

    it "converts signed integers" do
      Cradare2::AddressUtils.to_u64?(4198400).should eq(4198400_u64)
    end

    it "parses hex string addresses with 0x prefix" do
      Cradare2::AddressUtils.to_u64?("0x401000").should eq(4198400_u64)
      Cradare2::AddressUtils.to_u64?("0X401000").should eq(4198400_u64)
      Cradare2::AddressUtils.to_u64?("0x140001000").should eq(0x140001000_u64)
    end

    it "parses decimal string offsets without 0x prefix" do
      Cradare2::AddressUtils.to_u64?("4198400").should eq(4198400_u64)
      Cradare2::AddressUtils.to_u64?("0").should eq(0_u64)
    end

    it "returns nil for unresolved symbol names" do
      Cradare2::AddressUtils.to_u64?("sym.main").should be_nil
      Cradare2::AddressUtils.to_u64?("entrypoint").should be_nil
    end
  end

  describe ".to_u64" do
    it "defaults to 0_u64 when parsing fails" do
      Cradare2::AddressUtils.to_u64("invalid").should eq(0_u64)
      Cradare2::AddressUtils.to_u64("0x1000").should eq(0x1000_u64)
    end
  end
end
