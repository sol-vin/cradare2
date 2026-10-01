require "./spec_helper"

describe "SourceMap O(log N) Binary Search" do
  it "finds instructions containing address within size bounds via binary search" do
    reader = Cradare2::Lines::SourceReader.new
    map = Cradare2::Lines::SourceMap.new(reader)

    # Insert instructions with gaps:
    # 0x1000 - 0x1005 (size 5)
    # 0x1010 - 0x1018 (size 8)
    # 0x1020 - 0x1024 (size 4)
    map.add(0x1000_u64, "app.cr", 10, opcode: "mov rax, 1", size: 5)
    map.add(0x1010_u64, "app.cr", 11, opcode: "add rax, 2", size: 8)
    map.add(0x1020_u64, "app.cr", 12, opcode: "ret", size: 4)

    # Exact matches
    ins = map.find_instruction_containing(0x1000_u64)
    ins.should_not be_nil
    ins.not_nil!.address.should eq(0x1000_u64)

    ins2 = map.find_instruction_containing(0x1010_u64)
    ins2.should_not be_nil
    ins2.not_nil!.address.should eq(0x1010_u64)

    # Within bounds of 0x1010..0x1018
    ins_mid = map.find_instruction_containing(0x1013_u64)
    ins_mid.should_not be_nil
    ins_mid.not_nil!.address.should eq(0x1010_u64)

    ins_last_byte = map.find_instruction_containing(0x1017_u64)
    ins_last_byte.should_not be_nil
    ins_last_byte.not_nil!.address.should eq(0x1010_u64)

    # In gap between 0x1005 and 0x1010 -> nil
    map.find_instruction_containing(0x1006_u64).should be_nil
    map.find_instruction_containing(0x100f_u64).should be_nil

    # Outside upper bounds
    map.find_instruction_containing(0x1025_u64).should be_nil

    # Before lower bounds
    map.find_instruction_containing(0x0fff_u64).should be_nil
  end

  it "clears sorted index on clear" do
    map = Cradare2::Lines::SourceMap.new
    map.add(0x1000_u64, "main.cr", 1, size: 4)
    map.find_instruction_containing(0x1002_u64).should_not be_nil

    map.clear
    map.find_instruction_containing(0x1002_u64).should be_nil
  end
end
