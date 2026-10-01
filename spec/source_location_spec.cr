require "./spec_helper"

describe Cradare2::Lines::SourceLocation do
  it "initializes correctly and normalizes file paths" do
    loc = Cradare2::Lines::SourceLocation.new(
      file: "src\\my_app\\player.cr",
      line: 42,
      column: 15,
      source_code: "  health = 100"
    )

    loc.file.should eq("src\\my_app\\player.cr")
    loc.normalized_file.should eq("src/my_app/player.cr")
    loc.basename.should eq("player.cr")
    loc.line.should eq(42)
    loc.column.should eq(15)
    loc.source_code.should eq("  health = 100")
  end

  it "formats to_s with and without column" do
    loc1 = Cradare2::Lines::SourceLocation.new("main.cr", 10, 5)
    loc1.to_s.should eq("main.cr:10:5")

    loc2 = Cradare2::Lines::SourceLocation.new("main.cr", 10, 0)
    loc2.to_s.should eq("main.cr:10")
  end

  it "implements equality correctly" do
    loc1 = Cradare2::Lines::SourceLocation.new("src/main.cr", 10, 5)
    loc2 = Cradare2::Lines::SourceLocation.new("src\\main.cr", 10, 5)
    loc3 = Cradare2::Lines::SourceLocation.new("src/main.cr", 11, 5)
    loc4 = Cradare2::Lines::SourceLocation.new("src/main.cr", 10, 6)

    loc1.should eq(loc2)
    loc1.should_not eq(loc3)
    loc1.should_not eq(loc4)
  end
end

describe Cradare2::Lines::InstructionMapping do
  it "stores instruction properties and formats to_s" do
    loc = Cradare2::Lines::SourceLocation.new("main.cr", 5, 2, "x = 42")
    ins = Cradare2::Lines::InstructionMapping.new(
      address: 0x401050_u64,
      size: 4,
      opcode: "mov eax, 0x2a",
      bytes: "b82a000000",
      location: loc,
      function_name: "main"
    )

    ins.address.should eq(0x401050_u64)
    ins.size.should eq(4)
    ins.opcode.should eq("mov eax, 0x2a")
    ins.bytes.should eq("b82a000000")
    ins.function_name.should eq("main")
    ins.location.should eq(loc)
    ins.to_s.should contain("0x401050: mov eax, 0x2a -> main.cr:5:2")
  end
end

describe Cradare2::Lines::LineInstructionGroup do
  it "manages a collection of instructions for a single source line" do
    group = Cradare2::Lines::LineInstructionGroup.new("src/math.cr", 12, "  sum = a + b")

    loc = Cradare2::Lines::SourceLocation.new("src/math.cr", 12)
    ins1 = Cradare2::Lines::InstructionMapping.new(0x1000_u64, 3, "mov eax, ecx", "89c8", loc)
    ins2 = Cradare2::Lines::InstructionMapping.new(0x1003_u64, 2, "add eax, edx", "01d0", loc)
    ins3 = Cradare2::Lines::InstructionMapping.new(0x1005_u64, 4, "mov [rbp-4], eax", "8945fc", loc)

    group.add_instruction(ins1)
    group.add_instruction(ins2)
    group.add_instruction(ins3)

    group.count.should eq(3)
    group.file.should eq("src/math.cr")
    group.line.should eq(12)
    group.source_code.should eq("  sum = a + b")
    group.min_address.should eq(0x1000_u64)
    group.max_address.should eq(0x1009_u64) # 0x1005 + 4 bytes
    group.total_size.should eq(9)           # 3 + 2 + 4
    group.basename.should eq("math.cr")
  end

  it "handles empty instruction groups gracefully" do
    group = Cradare2::Lines::LineInstructionGroup.new("empty.cr", 1)
    group.count.should eq(0)
    group.min_address.should eq(0_u64)
    group.max_address.should eq(0_u64)
    group.total_size.should eq(0)
  end
end
