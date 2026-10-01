require "./spec_helper"

describe "Source Line Matching Engine Exhaustive Suite" do
  describe "Lines::SourceLocation" do
    it "normalizes Windows and POSIX file paths" do
      loc_win = Cradare2::Lines::SourceLocation.new("C:\\Users\\Ian\\dev\\game.cr", 42, 5)
      loc_posix = Cradare2::Lines::SourceLocation.new("C:/Users/Ian/dev/game.cr", 42, 5)

      loc_win.normalized_file.should eq("C:/Users/Ian/dev/game.cr")
      loc_win.normalized_path.should eq("C:/Users/Ian/dev/game.cr")
      loc_win.basename.should eq("game.cr")
      loc_win.should eq(loc_posix)
    end

    it "formats string representation with and without column" do
      loc_col = Cradare2::Lines::SourceLocation.new("src/main.cr", 15, 3)
      loc_no_col = Cradare2::Lines::SourceLocation.new("src/main.cr", 15, 0)

      loc_col.to_s.should eq("src/main.cr:15:3")
      loc_no_col.to_s.should eq("src/main.cr:15")
    end
  end

  describe "Lines::InstructionMapping & LineInstructionGroup" do
    it "tracks instruction metadata and formats to_s" do
      loc = Cradare2::Lines::SourceLocation.new("src/math.cr", 10, 2)
      ins = Cradare2::Lines::InstructionMapping.new(
        address: 0x140001000_u64,
        size: 3,
        opcode: "add eax, edx",
        bytes: "01d0",
        location: loc,
        function_name: "Math#add"
      )

      ins.address.should eq(0x140001000_u64)
      ins.size.should eq(3)
      ins.opcode.should eq("add eax, edx")
      ins.bytes.should eq("01d0")
      ins.function_name.should eq("Math#add")
      ins.to_s.should eq("0x140001000: add eax, edx -> src/math.cr:10:2")
    end

    it "calculates group address ranges and sizes correctly" do
      group = Cradare2::Lines::LineInstructionGroup.new(file: "src/calc.cr", line: 20)
      group.min_address.should eq(0_u64)
      group.max_address.should eq(0_u64)
      group.total_size.should eq(0)
      group.count.should eq(0)

      loc = Cradare2::Lines::SourceLocation.new("src/calc.cr", 20)
      ins1 = Cradare2::Lines::InstructionMapping.new(0x1000_u64, 4, "mov eax, 1", "b801000000", loc)
      ins2 = Cradare2::Lines::InstructionMapping.new(0x1004_u64, 2, "ret", "c3", loc)

      group.add_instruction(ins1)
      group.add_instruction(ins2)

      group.count.should eq(2)
      group.min_address.should eq(0x1000_u64)
      group.max_address.should eq(0x1006_u64) # 0x1004 + 2
      group.total_size.should eq(6)
    end
  end

  describe "Lines::SourceReader" do
    it "registers virtual source and reads lines with 1-based indexing" do
      reader = Cradare2::Lines::SourceReader.new
      content = "def hello\n  puts \"world\"\nend"
      reader.register_source("virtual/test.cr", content)

      reader.exists?("virtual/test.cr").should be_true
      reader.has_file?("test.cr").should be_true
      reader.line_count("virtual/test.cr").should eq(3)

      reader.read_line("virtual/test.cr", 1).should eq("def hello")
      reader.read_line("virtual/test.cr", 2).should eq("  puts \"world\"")
      reader.read_line("virtual/test.cr", 3).should eq("end")
      reader.read_line("virtual/test.cr", 4).should be_nil
      reader.read_line("virtual/test.cr", 0).should be_nil
      reader.read_line("virtual/test.cr", -1).should be_nil
    end

    it "reads contextual blocks with symmetric windows" do
      reader = Cradare2::Lines::SourceReader.new
      lines = (1..10).map { |i| "line #{i}" }.join("\n")
      reader.set_virtual_source("source.cr", lines)

      ctx = reader.read_context("source.cr", 5, window: 2)
      ctx.size.should eq(5)
      ctx.map(&.[:line]).should eq([3, 4, 5, 6, 7])
      ctx.find(&.[:current]).try(&.[:line]).should eq(5)

      # Boundary at beginning
      ctx_start = reader.read_context("source.cr", 1, before: 2, after: 2)
      ctx_start.map(&.[:line]).should eq([1, 2, 3])

      # Boundary at end
      ctx_end = reader.read_context("source.cr", 10, before: 2, after: 2)
      ctx_end.map(&.[:line]).should eq([8, 9, 10])
    end

    it "applies path prefix mappings" do
      reader = Cradare2::Lines::SourceReader.new
      reader.register_source("C:/local/src/player.cr", "class Player\nend")

      reader.map_path("/docker/build/src", "C:/local/src")
      reader.exists?("/docker/build/src/player.cr").should be_true
      reader.read_line("/docker/build/src/player.cr", 1).should eq("class Player")

      reader.clear_mappings
      reader.clear_cache
      reader.exists?("/docker/build/src/player.cr").should be_false
    end
  end

  describe "Lines::SourceMap" do
    it "adds instructions and performs O(log N) binary search lookup" do
      reader = Cradare2::Lines::SourceReader.new
      reader.register_source("math.cr", "def calc\n  x = 1\n  y = 2\nend")

      map = Cradare2::Lines::SourceMap.new(reader)
      # Add 3 instructions across 2 lines
      map.add(0x1000_u64, "math.cr", 2, opcode: "mov eax, 1", size: 5)
      map.add(0x1005_u64, "math.cr", 3, opcode: "mov edx, 2", size: 5)
      map.add(0x100a_u64, "math.cr", 4, opcode: "ret", size: 1)

      map.size.should eq(3)
      map.empty?.should be_false

      # Exact address matches
      map.find_by_address(0x1000_u64).try(&.line).should eq(2)
      map.find_by_address(0x1005_u64).try(&.line).should eq(3)

      # Binary search containing addresses (interior offsets)
      # Address 0x1002 is inside 0x1000..0x1005
      ins_contain = map.find_instruction_containing(0x1002_u64)
      ins_contain.should_not be_nil
      ins_contain.not_nil!.address.should eq(0x1000_u64)
      ins_contain.not_nil!.location.line.should eq(2)

      # Address 0x1007 is inside 0x1005..0x100a
      ins_contain2 = map.find_instruction_containing(0x1007_u64)
      ins_contain2.should_not be_nil
      ins_contain2.not_nil!.address.should eq(0x1005_u64)

      # Address out of range
      map.find_instruction_containing(0x0500_u64).should be_nil
      map.find_instruction_containing(0x2000_u64).should be_nil
    end

    it "finds instructions by line and file basename" do
      map = Cradare2::Lines::SourceMap.new
      map.add(0x2000_u64, "C:/projects/game/src/player.cr", 10, opcode: "nop", size: 1)
      map.add(0x2001_u64, "C:/projects/game/src/player.cr", 10, opcode: "ret", size: 1)

      # Full path lookup
      insts = map.find_by_line("C:/projects/game/src/player.cr", 10)
      insts.size.should eq(2)

      # Basename lookup
      insts_base = map.find_by_line("player.cr", 10)
      insts_base.size.should eq(2)

      map.lines_for_file("player.cr").should eq([10])
      map.files.should contain("C:/projects/game/src/player.cr")
    end

    it "formats interleaved view for functions and full binary" do
      reader = Cradare2::Lines::SourceReader.new
      reader.register_source("sample.cr", "def foo\n  puts 123\nend")

      map = Cradare2::Lines::SourceMap.new(reader)
      map.add(0x3000_u64, "sample.cr", 2, opcode: "mov edi, 123", size: 5, bytes: "bf7b000000", function_name: "foo")
      map.add(0x3005_u64, "sample.cr", 2, opcode: "call puts", size: 5, bytes: "e8f6ffffff", function_name: "foo")

      view_fn = map.format_interleaved_view("foo")
      view_fn.should contain("File: sample.cr")
      view_fn.should contain("Line    2: |   puts 123")
      view_fn.should contain("0x00003000  bf7b000000        mov edi, 123")
      view_fn.should contain("0x00003005  e8f6ffffff        call puts")

      view_all = map.format_interleaved_view
      view_all.should contain("Line    2:")

      empty_map = Cradare2::Lines::SourceMap.new
      empty_map.format_interleaved_view.should eq("No source line mappings found.")
    end

    it "synchronizes mappings to radare2 via CL and CC commands" do
      executed = [] of String
      handler = ->(cmd : String) {
        executed << cmd
        ""
      }
      client = Cradare2.mock(handler)

      reader = Cradare2::Lines::SourceReader.new
      reader.register_source("src/test.cr", "puts 1")

      map = Cradare2::Lines::SourceMap.new(reader)
      map.add(0x4000_u64, "src/test.cr", 1, opcode: "nop", size: 1)

      count = map.sync_to_r2(client, annotate_comments: true)
      count.should eq(1)

      # Check CL registration
      executed.should contain("CL 0x4000 src/test.cr:1")
      # Check CC comment
      executed.any? { |c| c.starts_with?("CC \"test.cr:1 | puts 1\" @ 0x4000") }.should be_true
      # Check dwarf line config
      executed.should contain("e asm.dwarf=true")
    end
  end

  describe "Lines::R2CodelineProvider & LineResolver" do
    it "queries and parses radare2 CLj json table" do
      clj_output = [
        {"addr" => 0x5000_i64, "file" => "main.cr", "line" => 4, "colu" => 2},
        {"addr" => 0x5010_i64, "file" => "util.cr", "line" => 12, "colu" => 0},
      ].to_json

      handler = ->(cmd : String) {
        cmd == "CLj" ? clj_output : "[]"
      }
      client = Cradare2.mock(handler)
      provider = Cradare2::Lines::R2CodelineProvider.new(client)
      provider.available?.should be_true
      provider.name.should eq("radare2_codelines")

      loc = provider.resolve_address(0x5000_u64)
      loc.should_not be_nil
      loc.not_nil!.file.should eq("main.cr")
      loc.not_nil!.line.should eq(4)
      loc.not_nil!.column.should eq(2)
    end

    it "resolves instructions through the provider chain in LineResolver" do
      clj_output = [
        {"addr" => 0x6000_i64, "file" => "game.cr", "line" => 8, "colu" => 0},
      ].to_json

      handler = ->(cmd : String) {
        cmd == "CLj" ? clj_output : "[]"
      }
      client = Cradare2.mock(handler)
      resolver = Cradare2::Lines::LineResolver.new(client)

      # Build model instructions
      ins1 = Cradare2::Model::Instruction.new(
        offset: 0x6000_u64,
        size: 3,
        opcode: "xor eax, eax",
        bytes: "31c0"
      )
      ins2 = Cradare2::Model::Instruction.new(
        offset: 0x6003_u64,
        size: 1,
        opcode: "ret",
        bytes: "c3"
      )

      map = resolver.resolve_instructions([ins1, ins2], "Game#init")
      map.size.should eq(1) # ins1 resolved, ins2 unresolved
      map.find_by_address(0x6000_u64).try(&.line).should eq(8)
    end
  end
end
