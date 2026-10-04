require "./spec_helper"

describe "Memory DSL 128-bit QWORD & Typed Array Operations" do
  it "reads 128-bit unsigned and signed integers in Little and Big Endian" do
    mock = Cradare2::Transport::MockTransport.new do |cmd|
      if cmd.starts_with?("pxj 16 @ 0x1000")
        # 16 bytes: 01 00 00 00 00 00 00 00  02 00 00 00 00 00 00 00
        # low = 1, high = 2 => u128 = (2 << 64) | 1
        "[1, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0]"
      else
        ""
      end
    end

    client = Cradare2::Client.new(mock)
    val_le = client.memory.read_u128(0x1000)
    expected_le = UInt128.new(1) | (UInt128.new(2) << 64)
    val_le.should eq(expected_le)
    client.memory.read_qword(0x1000).should eq(expected_le)
    client.memory.read_i128(0x1000).should eq(expected_le.to_i128!)

    val_be = client.memory.read_u128(0x1000, format: IO::ByteFormat::BigEndian)
    val_be.should be_a(UInt128)
  end

  it "writes 128-bit unsigned integers via write_u128 and write_qword" do
    executed = [] of String
    mock = Cradare2::Transport::MockTransport.new do |cmd|
      executed << cmd
      ""
    end

    client = Cradare2::Client.new(mock)
    val = UInt128.new(0x1122334455667788_u64) | (UInt128.new(0xAABBCCDDEEFF0011_u64) << 64)
    client.memory.write_u128(0x2000, val)

    executed.size.should eq(1)
    executed.first.should start_with("wx ")
    executed.first.should contain("@ 0x2000")

    client.memory.write_qword(0x2000, val)
    executed.size.should eq(2)
  end

  it "reads arrays of 32-bit pointers, u8, u32, u64, and f32" do
    mock = Cradare2::Transport::MockTransport.new do |cmd|
      if cmd.starts_with?("pxj 16 @ 0x3000")
        # Four 32-bit words: 10, 20, 30, 40
        "[10, 0, 0, 0, 20, 0, 0, 0, 30, 0, 0, 0, 40, 0, 0, 0]"
      elsif cmd.starts_with?("pxj 4 @ 0x3010")
        "[1, 2, 3, 4]"
      elsif cmd.starts_with?("pxj 8 @ 0x3020")
        "[0, 0, 128, 63, 0, 0, 0, 64]" # Float32: 1.0f, 2.0f
      else
        "[]"
      end
    end

    client = Cradare2::Client.new(mock)

    # 32-bit pointer array
    ptrs32 = client.memory.read_pointer32_array(0x3000, 4)
    ptrs32.should eq([10_u32, 20_u32, 30_u32, 40_u32])

    # 32-bit int array
    u32s = client.memory.read_u32_array(0x3000, 4)
    u32s.should eq([10_u32, 20_u32, 30_u32, 40_u32])

    # 8-bit array
    u8s = client.memory.read_u8_array(0x3010, 4)
    u8s.should eq([1_u8, 2_u8, 3_u8, 4_u8])

    # f32 array
    f32s = client.memory.read_f32_array(0x3020, 2)
    f32s.size.should eq(2)
    f32s[0].should eq(1.0_f32)
    f32s[1].should eq(2.0_f32)
  end

  it "searches hex patterns with spaces stripped" do
    executed = [] of String
    mock = Cradare2::Transport::MockTransport.new do |cmd|
      executed << cmd
      "0x00401000 hit 1\n0x00402000 hit 2"
    end

    client = Cradare2::Client.new(mock)
    hits = client.memory.search_hex("48 89 5c 24")
    executed.should contain("/x 48895c24")
    hits.should eq([0x00401000_u64, 0x00402000_u64])
  end

  it "supports hexdiff command" do
    executed = [] of String
    mock = Cradare2::Transport::MockTransport.new do |cmd|
      executed << cmd
      "DIFF_RESULT"
    end

    client = Cradare2::Client.new(mock)
    res = client.memory.hexdiff(0x1000, 0x2000, 32)
    res.should eq("DIFF_RESULT")
    executed.should contain("cc 32 @ 0x2000 @ 0x1000")
  end
end
