require "./spec_helper"

describe Cradare2::Lines::SourceMap do
  it "records and queries bidirectional mappings" do
    reader = Cradare2::Lines::SourceReader.new
    reader.register_source("calc.cr", "def add(a, b)\n  a + b\nend")

    map = Cradare2::Lines::SourceMap.new(reader)
    map.empty?.should be_true

    # Line 1: def add(a, b) -> 0x401000, 0x401004
    map.add(0x401000_u64, "calc.cr", 1, 1, "sub rsp, 0x28", 4, "4883ec28", "add")
    map.add(0x401004_u64, "calc.cr", 1, 1, "mov [rsp+8], rcx", 5, "48894c2408", "add")

    # Line 2: a + b -> 0x401009, 0x40100c
    map.add(0x401009_u64, "calc.cr", 2, 3, "mov eax, ecx", 2, "89c8", "add")
    map.add(0x40100c_u64, "calc.cr", 2, 5, "add eax, edx", 2, "01d0", "add")

    # Line 3: end -> 0x40100e, 0x401012
    map.add(0x40100e_u64, "calc.cr", 3, 1, "add rsp, 0x28", 4, "4883c428", "add")
    map.add(0x401012_u64, "calc.cr", 3, 1, "ret", 1, "c3", "add")

    map.size.should eq(6)
    map.empty?.should be_false

    # Query by exact address
    loc1 = map.find_by_address(0x401000_u64)
    loc1.should_not be_nil
    loc1.not_nil!.line.should eq(1)
    loc1.not_nil!.source_code.should eq("def add(a, b)")

    loc2 = map.find_by_address(0x40100c_u64)
    loc2.should_not be_nil
    loc2.not_nil!.line.should eq(2)
    loc2.not_nil!.source_code.should eq("  a + b")

    # Query non-existent address
    map.find_by_address(0x999999_u64).should be_nil

    # Query by line
    line2_ins = map.find_by_line("calc.cr", 2)
    line2_ins.size.should eq(2)
    line2_ins[0].address.should eq(0x401009_u64)
    line2_ins[1].address.should eq(0x40100c_u64)

    # Query line with basename
    line1_ins = map.find_by_line("calc.cr", 1)
    line1_ins.size.should eq(2)

    # Query non-existent line
    map.find_by_line("calc.cr", 99).should be_empty
  end

  it "finds instructions containing address within instruction byte size" do
    map = Cradare2::Lines::SourceMap.new
    # Instruction from 0x401000 to 0x401004 (size 4)
    map.add(0x401000_u64, "foo.cr", 5, 0, "sub rsp, 0x20", 4, "4883ec20")

    # Exact start address
    map.find_instruction_containing(0x401000_u64).should_not be_nil

    # Byte 2 of the 4-byte instruction
    ins_mid = map.find_instruction_containing(0x401002_u64)
    ins_mid.should_not be_nil
    ins_mid.not_nil!.address.should eq(0x401000_u64)

    # Address right after instruction (0x401004) -> nil
    map.find_instruction_containing(0x401004_u64).should be_nil
  end

  it "groups instructions by consecutive source lines" do
    reader = Cradare2::Lines::SourceReader.new
    reader.register_source("group_test.cr", "line 1\nline 2\nline 3")

    map = Cradare2::Lines::SourceMap.new(reader)
    map.add(0x1000_u64, "group_test.cr", 1, 0, "nop", 1, "90", "fn")
    map.add(0x1001_u64, "group_test.cr", 1, 0, "nop", 1, "90", "fn")
    map.add(0x1002_u64, "group_test.cr", 2, 0, "xor eax, eax", 2, "31c0", "fn")
    map.add(0x1004_u64, "group_test.cr", 3, 0, "ret", 1, "c3", "fn")

    groups = map.groups_for_range(0x1000_u64, 0x1005_u64)
    groups.size.should eq(3)

    groups[0].line.should eq(1)
    groups[0].count.should eq(2)
    groups[0].min_address.should eq(0x1000_u64)
    groups[0].max_address.should eq(0x1002_u64)

    groups[1].line.should eq(2)
    groups[1].count.should eq(1)
    groups[1].min_address.should eq(0x1002_u64)

    groups[2].line.should eq(3)
    groups[2].count.should eq(1)
  end

  it "formats a readable interleaved view of source and assembly" do
    reader = Cradare2::Lines::SourceReader.new
    reader.register_source("interleave.cr", "def foo\n  x = 1\n  ret\nend")

    map = Cradare2::Lines::SourceMap.new(reader)
    map.add(0x2000_u64, "interleave.cr", 1, 0, "push rbp", 1, "55", "foo")
    map.add(0x2001_u64, "interleave.cr", 2, 0, "mov eax, 1", 5, "b801000000", "foo")
    map.add(0x2006_u64, "interleave.cr", 3, 0, "pop rbp", 1, "5d", "foo")
    map.add(0x2007_u64, "interleave.cr", 3, 0, "ret", 1, "c3", "foo")

    groups = map.groups_for_function_name("foo")
    view = map.format_interleaved_view(groups)

    view.should contain("File: interleave.cr")
    view.should contain("Line    1: | def foo")
    view.should contain("Line    2: |   x = 1")
    view.should contain("Line    3: |   ret")
    view.should contain("0x00002000")
    view.should contain("push rbp")
    view.should contain("mov eax, 1")
    view.should contain("ret")
  end

  it "synchronizes line tables and comments with radare2" do
    executed_commands = [] of String
    mock_client = SpecFixtures.build_mock_with_handler do |cmd|
      executed_commands << cmd
      ""
    end

    reader = Cradare2::Lines::SourceReader.new
    reader.register_source("sync.cr", "x = 10\ny = 20")

    map = Cradare2::Lines::SourceMap.new(reader)
    map.add(0x401000_u64, "sync.cr", 1, 0, "mov eax, 10", 5, "b80a000000", source_text: "x = 10")
    map.add(0x401005_u64, "sync.cr", 2, 0, "mov ecx, 20", 5, "b914000000", source_text: "y = 20")

    count = map.sync_to_r2(mock_client, annotate_comments: true)
    count.should eq(2)

    # Verify CL registration
    executed_commands.should contain("CL 0x401000 sync.cr:1")
    executed_commands.should contain("CL 0x401005 sync.cr:2")

    # Verify CC comment registration
    executed_commands.should contain("CC \"sync.cr:1 | x = 10\" @ 0x401000")
    executed_commands.should contain("CC \"sync.cr:2 | y = 20\" @ 0x401005")

    # Verify asm.dwarf enabled
    executed_commands.should contain("e asm.dwarf=true")
  end

  it "handles Windows absolute paths in sync_to_r2 without colon conflict" do
    executed_commands = [] of String
    mock_client = SpecFixtures.build_mock_with_handler do |cmd|
      executed_commands << cmd
      ""
    end

    map = Cradare2::Lines::SourceMap.new
    map.add(0x401000_u64, "C:\\Users\\Ian\\project\\main.cr", 10, 0, "nop", 1, "90")

    map.sync_to_r2(mock_client)

    # Verify path colon was converted to safe forward-slash path (no colon after drive letter)
    cl_cmd = executed_commands.find { |c| c.starts_with?("CL 0x401000") }
    cl_cmd.should_not be_nil
    # Should not contain "C:" directly in the file:line parameter
    param = cl_cmd.not_nil!.split(' ')[2]
    # Parameter should only have ONE colon (the line separator at the end)
    param.count(':').should eq(1)
  end

  it "clears mappings cleanly" do
    map = Cradare2::Lines::SourceMap.new
    map.add(0x1000_u64, "test.cr", 1, 0, "nop", 1)
    map.size.should eq(1)

    map.clear
    map.size.should eq(0)
    map.empty?.should be_true
    map.find_by_address(0x1000_u64).should be_nil
  end
end
