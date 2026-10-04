require "./spec_helper"

describe Cradare2::Gdb::Client do
  it "calculates correct 8-bit checksum and formats packets" do
    # Command "m70000000,4"
    # Checksum is sum of bytes & 0xFF
    cmd = "m70000000,4"
    csum = Cradare2::Gdb::Client.calculate_checksum(cmd)
    csum.should be_a(UInt8)

    packet = Cradare2::Gdb::Client.format_packet(cmd)
    packet.should start_with("$m70000000,4#")
    packet.size.should eq(cmd.size + 4) # '$' + cmd + '#' + 2 hex digits
  end

  it "verifies checksum of simple commands" do
    # '?' packet checksum: '?' is 0x3F => checksum is 0x3F
    Cradare2::Gdb::Client.calculate_checksum("?").should eq(0x3F_u8)
    Cradare2::Gdb::Client.format_packet("?").should eq("$?#3f")
  end
end
