require "./spec_helper"
require "../src/cradare2/plugin/dispatcher"

describe "Massive Exhaustive Crystal Plugin Test Suite" do
  before_each do
    Cradare2::Util::Demangler.clear_cache
  end

  describe "1. Demangler: Exhaustive PDB Character Matrix" do
    it "tests every single ASCII printable punctuation escape" do
      ascii_escapes = {
        "_2A." => "*",
        ".20." => " ",
        ".21." => "!",
        ".22." => "\"",
        ".23." => "#",
        ".24." => "$",
        ".25." => "%",
        ".26." => "&",
        ".27." => "'",
        ".28." => "(",
        ".29." => ")",
        ".2B." => "+",
        ".2C." => ",",
        ".2D." => "-",
        ".2E." => ".",
        ".2F." => "/",
        ".3A." => ":",
        ".3B." => ";",
        ".3C." => "<",
        ".3D." => "=",
        ".3E." => ">",
        ".3F." => "?",
        ".40." => "@",
        ".5B." => "[",
        ".5C." => "\\",
        ".5D." => "]",
        ".5E." => "^",
        ".5F." => "_",
        ".60." => "`",
        ".7B." => "{",
        ".7C." => "|",
        ".7D." => "}",
        ".7E." => "~",
      }

      ascii_escapes.each do |escape_seq, expected_char|
        encoded = "pdb.prefix#{escape_seq}suffix"
        decoded = Cradare2::Util::Demangler.decode_pdb_escapes(encoded)
        decoded.should eq("pdb.prefix#{expected_char}suffix")
      end
    end

    it "decodes leading _XX. escape sequences at the beginning of identifiers" do
      # Leading _2A. -> *
      Cradare2::Util::Demangler.decode_pdb_escapes("_2A.Foo").should eq("*Foo")
      # Leading _7E. -> ~
      Cradare2::Util::Demangler.decode_pdb_escapes("_7E.Bar").should eq("~Bar")
      # Leading _40. -> @
      Cradare2::Util::Demangler.decode_pdb_escapes("_40.Baz").should eq("@Baz")
    end

    it "demangles all standard Crystal operators encoded in PDB symbols" do
      ops = {
        ".2B."         => "+",
        ".2D."         => "-",
        "_2A."         => "*",
        ".2F."         => "/",
        ".25."         => "%",
        ".26."         => "&",
        ".7C."         => "|",
        ".5E."         => "^",
        ".7E."         => "~",
        ".3D..3D."     => "==",
        ".21..3D."     => "!=",
        ".3C."         => "<",
        ".3C..3D."     => "<=",
        ".3E."         => ">",
        ".3E..3D."     => ">=",
        ".3C..3D..3E." => "<=>",
        ".3D..3D..3D." => "===",
        ".3D..7E."     => "=~",
        ".21..7E."     => "!~",
        ".3C..3C."     => "<<",
        ".3E..3E."     => ">>",
        ".5B..5D."     => "[]",
        ".5B..5D..3D." => "[]=",
        ".5B..5D..3F." => "[]?",
        "_2A._2A."     => "**",
        ".26..2B."     => "&+",
        ".26..2D."     => "&-",
        ".26._2A."     => "&*",
        ".26._2A._2A." => "&**",
      }

      ops.each do |pdb_op, expected_op|
        sym = "pdb._2A.MyType.23.#{pdb_op}.3C.Int32.3E..3A.Int32"
        demangled = Cradare2::Util::Demangler.demangle(sym)
        demangled.should eq("MyType##{expected_op}<Int32>:Int32")
      end
    end

    it "demangles deeply nested generics, unions, and tuples" do
      # Deeply nested generic Hash
      sym1 = "pdb._2A.Hash.28.String.2C..20.Array.28.Tuple.28.Int32.2C..20.Float64.29..29..29..23.get.3A.Nil"
      Cradare2::Util::Demangler.demangle(sym1).should eq("Hash(String, Array(Tuple(Int32, Float64)))#get:Nil")

      # Union types
      sym2 = "pdb._2A.Result.28.Int32.20..7C..20.String.20..7C..20.Nil.29..23.unwrap.3A.Int32"
      Cradare2::Util::Demangler.demangle(sym2).should eq("Result(Int32 | String | Nil)#unwrap:Int32")

      # Named tuple and proc
      sym3 = "pdb._2A.Proc.28.Int32.2C..20.String.2C..20.Void.29..23.call.3A.Void"
      Cradare2::Util::Demangler.demangle(sym3).should eq("Proc(Int32, String, Void)#call:Void")
    end

    it "handles demangler cache retention and stress testing" do
      500.times do |i|
        raw = "pdb._2A.Module#{i}.3A..3A.Class#{i}.23.method#{i}.3A.Int32"
        expected = "Module#{i}::Class#{i}#method#{i}:Int32"
        Cradare2::Util::Demangler.demangle(raw).should eq(expected)
      end

      # Second pass should hit cache immediately
      500.times do |i|
        raw = "pdb._2A.Module#{i}.3A..3A.Class#{i}.23.method#{i}.3A.Int32"
        expected = "Module#{i}::Class#{i}#method#{i}:Int32"
        Cradare2::Util::Demangler.demangle(raw).should eq(expected)
      end

      Cradare2::Util::Demangler.clear_cache
      # Cache cleared, should still demangle correctly
      Cradare2::Util::Demangler.demangle("pdb._2A.Module0.3A..3A.Class0.23.method0.3A.Int32").should eq("Module0::Class0#method0:Int32")
    end

    it "guarantees demangler idempotency" do
      samples = [
        "*Foo#bar:Int32",
        "MyModule::Helper.calculate:Float64",
        "Array(Int32)#[](Int32):Int32",
        "GC_malloc",
        "main",
        "Unknown$Symbol#123",
      ]

      samples.each do |sample|
        d1 = Cradare2::Util::Demangler.demangle(sample)
        d2 = Cradare2::Util::Demangler.demangle(d1)
        d2.should eq(d1)
      end
    end
  end

  describe "2. Source Location & Range Calculations" do
    it "handles path normalization across operating systems" do
      loc_unix = Cradare2::Lines::SourceLocation.new("/home/user/src/app.cr", 42, 5)
      loc_win = Cradare2::Lines::SourceLocation.new("C:\\Users\\user\\src\\app.cr", 42, 5)
      loc_mixed = Cradare2::Lines::SourceLocation.new("C:/Users/user\\src/app.cr", 42, 5)

      loc_unix.basename.should eq("app.cr")
      loc_win.basename.should eq("app.cr")
      loc_mixed.basename.should eq("app.cr")

      loc_win.normalized_path.should eq("C:/Users/user/src/app.cr")
      loc_mixed.normalized_path.should eq("C:/Users/user/src/app.cr")
    end

    it "computes instruction span and total size accurately" do
      loc = Cradare2::Lines::SourceLocation.new("calc.cr", 10)
      ins1 = Cradare2::Lines::InstructionMapping.new(0x1000_u64, 5, "mov eax, 1", "b801000000", loc)
      ins2 = Cradare2::Lines::InstructionMapping.new(0x1005_u64, 2, "add eax, edx", "01d0", loc)
      ins3 = Cradare2::Lines::InstructionMapping.new(0x1007_u64, 1, "ret", "c3", loc)

      group = Cradare2::Lines::LineInstructionGroup.new("calc.cr", 10, "x = 1 + y", [ins1, ins2, ins3])
      group.min_address.should eq(0x1000_u64)
      group.max_address.should eq(0x1008_u64)
      group.count.should eq(3)
      group.total_size.should eq(8)
      group.address_range.should eq(0x1000_u64..0x1008_u64)
    end

    it "handles zero-sized instructions and extreme 64-bit addresses" do
      loc = Cradare2::Lines::SourceLocation.new("extreme.cr", 1)
      max_addr = 0xFFFF_FFFF_FFFF_FFF0_u64
      ins = Cradare2::Lines::InstructionMapping.new(max_addr, 1, "nop", "90", loc)
      group = Cradare2::Lines::LineInstructionGroup.new("extreme.cr", 1, nil, [ins])

      group.min_address.should eq(max_addr)
      group.max_address.should eq(max_addr + 1)
      group.count.should eq(1)
    end
  end

  describe "3. Source Reader: Virtual Files & Edge Cases" do
    it "handles line boundary conditions safely" do
      reader = Cradare2::Lines::SourceReader.new
      content = "Line 1\nLine 2\nLine 3"
      reader.register_source("bounds.cr", content)

      reader.has_file?("bounds.cr").should be_true
      reader.line_count("bounds.cr").should eq(3)

      # In-bounds lines
      reader.read_line("bounds.cr", 1).should eq("Line 1")
      reader.read_line("bounds.cr", 2).should eq("Line 2")
      reader.read_line("bounds.cr", 3).should eq("Line 3")

      # Out-of-bounds lines
      reader.read_line("bounds.cr", 0).should be_nil
      reader.read_line("bounds.cr", -1).should be_nil
      reader.read_line("bounds.cr", -100).should be_nil
      reader.read_line("bounds.cr", 4).should be_nil
      reader.read_line("bounds.cr", 999).should be_nil
    end

    it "handles Windows CRLF and Mac CR line endings seamlessly" do
      reader = Cradare2::Lines::SourceReader.new
      crlf_content = "def hello\r\n  puts \"world\"\r\nend\r\n"
      reader.register_source("crlf.cr", crlf_content)

      reader.line_count("crlf.cr").should eq(3)
      reader.read_line("crlf.cr", 1).should eq("def hello")
      reader.read_line("crlf.cr", 2).should eq("  puts \"world\"")
      reader.read_line("crlf.cr", 3).should eq("end")
    end

    it "extracts context windows correctly across beginning, middle, and end" do
      reader = Cradare2::Lines::SourceReader.new
      content = (1..10).map { |i| "code_line_#{i}" }.join("\n")
      reader.register_source("context.cr", content)

      # Beginning of file (clamped at line 1)
      ctx_beg = reader.read_context("context.cr", 2, window: 3)
      ctx_beg.size.should eq(5)
      ctx_beg.first[:line].should eq(1)
      ctx_beg.last[:line].should eq(5)

      # Middle of file
      ctx_mid = reader.read_context("context.cr", 5, window: 2)
      ctx_mid.size.should eq(5)
      ctx_mid.first[:line].should eq(3)
      ctx_mid.last[:line].should eq(7)

      # End of file (clamped at line 10)
      ctx_end = reader.read_context("context.cr", 9, window: 3)
      ctx_end.size.should eq(5)
      ctx_end.first[:line].should eq(6)
      ctx_end.last[:line].should eq(10)

      # Zero window size
      ctx_zero = reader.read_context("context.cr", 5, window: 0)
      ctx_zero.size.should eq(1)
      ctx_zero.first[:line].should eq(5)
      ctx_zero.first[:text].should eq("code_line_5")
    end

    it "safely returns nil for non-existent files" do
      reader = Cradare2::Lines::SourceReader.new
      reader.read_line("non_existent_file_12345.cr", 1).should be_nil
      reader.read_context("non_existent_file_12345.cr", 1).should be_empty
      reader.line_count("non_existent_file_12345.cr").should eq(0)
    end
  end

  describe "4. Source Map: Advanced Queries & Out-of-Order Assembly" do
    it "handles instructions added out of order and sorts them in groups" do
      reader = Cradare2::Lines::SourceReader.new
      reader.register_source("order.cr", "def foo\n  a = 1\n  b = 2\nend")

      map = Cradare2::Lines::SourceMap.new(reader)
      # Add in reverse/scrambled order
      map.add(0x3000_u64, "order.cr", 3, 0, "ret", 1, "c3", "foo")
      map.add(0x1000_u64, "order.cr", 1, 0, "push rbp", 1, "55", "foo")
      map.add(0x2000_u64, "order.cr", 2, 0, "mov eax, 1", 5, "b801000000", "foo")
      map.add(0x2005_u64, "order.cr", 2, 0, "mov edx, 2", 5, "ba02000000", "foo")

      groups = map.groups_for_function_name("foo")
      groups.size.should eq(3)
      groups[0].line.should eq(1)
      groups[0].min_address.should eq(0x1000_u64)

      groups[1].line.should eq(2)
      groups[1].instructions.size.should eq(2)
      groups[1].instructions[0].address.should eq(0x2000_u64)
      groups[1].instructions[1].address.should eq(0x2005_u64)

      groups[2].line.should eq(3)
      groups[2].min_address.should eq(0x3000_u64)
    end

    it "handles interior instruction address lookups" do
      map = Cradare2::Lines::SourceMap.new
      map.add(0x5000_u64, "interior.cr", 15, 0, "mov dword ptr [rsp + 0x10], 0x42", 8, "c744241042000000")

      # Exact start of instruction
      loc = map.find_by_address(0x5000_u64)
      loc.should_not be_nil
      loc.not_nil!.line.should eq(15)

      # Middle of 8-byte instruction (0x5000 + 4 = 0x5004)
      interior_ins = map.find_instruction_containing(0x5004_u64)
      interior_ins.should_not be_nil
      interior_ins.not_nil!.address.should eq(0x5000_u64)

      # Past the instruction (0x5008)
      map.find_instruction_containing(0x5008_u64).should be_nil
    end

    it "escapes quotes and semicolons properly in r2 comments" do
      executed_cmds = [] of String
      mock_client = SpecFixtures.build_mock_with_handler do |cmd|
        executed_cmds << cmd
        ""
      end

      reader = Cradare2::Lines::SourceReader.new
      reader.register_source("quote.cr", "puts \"hello; world\"")
      map = Cradare2::Lines::SourceMap.new(reader)
      map.add(0x1000_u64, "quote.cr", 1, 0, "call puts", 5)

      map.sync_to_r2(mock_client, annotate_comments: true)

      comment_cmd = executed_cmds.find { |c| c.starts_with?("CC ") }
      comment_cmd.should_not be_nil
      # Quotes and semicolons should be sanitized
      comment_cmd.not_nil!.should_not contain("; world\"")
      comment_cmd.not_nil!.should contain("hello, world'")
    end

    it "generates clean interleaved view when source code is missing" do
      map = Cradare2::Lines::SourceMap.new
      map.add(0x1000_u64, "missing.cr", 5, 0, "xor eax, eax", 2, "31c0", "test_fn")

      groups = map.groups_for_function_name("test_fn")
      view = map.format_interleaved_view(groups)
      view.should contain("File: missing.cr")
      view.should contain("(source unavailable)")
      view.should contain("xor eax, eax")
    end
  end

  describe "5. Line Resolver: JSON Edge Cases" do
    it "handles malformed or truncated CLj responses safely" do
      mock_client = SpecFixtures.build_mock_with_handler do |cmd|
        if cmd == "CLj"
          "{ malformed json [}"
        else
          "[]"
        end
      end

      resolver = Cradare2::Lines::LineResolver.new(mock_client)
      locs = resolver.resolve_from_r2_codelines
      locs.should be_empty
    end

    it "handles CLj entries with missing fields or alternate field names" do
      mock_client = SpecFixtures.build_mock_with_handler do |cmd|
        if cmd == "CLj"
          <<-JSON
          [
            {"file": "good.cr", "line": 10, "offset": 4096},
            {"file": "missing_line.cr", "offset": 5000},
            {"file": "missing_offset.cr", "line": 15},
            {"line": 20, "offset": 6000},
            {"file": "hex_offset.cr", "line": 25, "addr": 7000}
          ]
          JSON
        else
          "[]"
        end
      end

      resolver = Cradare2::Lines::LineResolver.new(mock_client)
      locs = resolver.resolve_from_r2_codelines
      locs.size.should be >= 1
      locs.first.file.should eq("good.cr")
      locs.first.line.should eq(10)
    end
  end

  describe "6. Plugin Command Dispatcher: Exhaustive Subcommand Suite" do
    it "dispatches help command on empty args, help, and invalid commands" do
      client = SpecFixtures.build_mock_with_handler { "" }
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

      dispatcher.dispatch("").should contain("Usage: crystal <command>")
      dispatcher.dispatch("help").should contain("Usage: crystal <command>")
      dispatcher.dispatch("invalid_command_xyz").should contain("Unknown crystal command: 'invalid_command_xyz'")
    end

    it "dispatches detect for Crystal binary" do
      client = SpecFixtures.build_mock_with_handler do |cmd|
        if cmd == "isj"
          %([{"name": "*Foo#bar:Nil", "vaddr": 4096}])
        else
          ""
        end
      end
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)
      dispatcher.dispatch("detect").should contain("Target is a Crystal binary!")
    end

    it "dispatches detect for Non-Crystal binary" do
      client = SpecFixtures.build_mock_with_handler do |cmd|
        if cmd == "isj"
          %([{"name": "main", "vaddr": 4096}])
        elsif cmd == "izj"
          %([])
        else
          ""
        end
      end
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)
      dispatcher.dispatch("detect").should contain("Target does NOT appear to be a Crystal binary.")
    end

    it "dispatches info command with summary metadata" do
      client = SpecFixtures.build_mock_with_handler do |cmd|
        if cmd == "isj"
          %([{"name": "*Foo#bar:Nil", "vaddr": 4096}])
        else
          ""
        end
      end
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)
      info = dispatcher.dispatch("info")
      info.should contain("=== Crystal Target Info ===")
      info.should contain("Crystal Binary: Yes")
    end

    it "dispatches demangle with single symbol and missing arg" do
      client = SpecFixtures.build_mock_with_handler { "" }
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

      dispatcher.dispatch("demangle").should contain("Usage: crystal demangle <symbol>")
      dispatcher.dispatch("demangle pdb._2A.add.3C.Int32.3E..3A.Int32").should contain("add<Int32>:Int32")
    end

    it "dispatches demangle-all with renaming" do
      applied_cmds = [] of String
      client = SpecFixtures.build_mock_with_handler do |cmd|
        applied_cmds << cmd
        if cmd == "aflj"
          %([{"offset": 4096, "name": "pdb._2A.add.3A.Int32", "size": 20}])
        elsif cmd == "isj"
          "[]"
        else
          ""
        end
      end
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

      out = dispatcher.dispatch("demangle-all")
      out.should contain("Demangled and renamed 1 functions/symbols")
      applied_cmds.any? { |c| c.starts_with?("afn ") }.should be_true
    end

    it "dispatches lines and lines sync" do
      executed_cmds = [] of String
      client = SpecFixtures.build_mock_with_handler do |cmd|
        executed_cmds << cmd
        ""
      end
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)
      client.crystal.lines.map.add(0x1000_u64, "main.cr", 10, 0, "nop", 1)

      dispatcher.dispatch("lines").should contain("Mapped Source Files")
      dispatcher.dispatch("lines sync").should contain("Synchronized 1 source line mappings")
      executed_cmds.should contain("CL 0x1000 main.cr:10")
    end

    it "dispatches src command with address parsing and context display" do
      client = SpecFixtures.build_mock_with_handler { "" }
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)
      client.crystal.lines.reader.register_source("foo.cr", "def foo\n  x = 1\n  ret\nend")
      client.crystal.lines.map.add(0x1000_u64, "foo.cr", 2, 0, "mov eax, 1", 5)

      # Missing arg
      dispatcher.dispatch("src").should contain("Usage: crystal src <addr>")

      # Invalid address format
      dispatcher.dispatch("src not_a_hex").should contain("Invalid address")

      # Address not mapped
      dispatcher.dispatch("src 0x9999").should contain("No source mapping found for address 0x9999")

      # Address mapped
      src_out = dispatcher.dispatch("src 0x1000")
      src_out.should contain("=== foo.cr:2")
      src_out.should contain("x = 1")
      src_out.should contain("▶")
    end

    it "dispatches asm command with file:line parsing" do
      client = SpecFixtures.build_mock_with_handler { "" }
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)
      client.crystal.lines.map.add(0x1000_u64, "bar.cr", 42, 0, "ret", 1, "c3")

      # Missing arg
      dispatcher.dispatch("asm").should contain("Usage: crystal asm <file:line>")

      # Invalid format (no colon)
      dispatcher.dispatch("asm invalid_no_colon").should contain("Invalid format")

      # Line not found
      dispatcher.dispatch("asm bar.cr:99").should contain("No instructions found for bar.cr:99")

      # Line found
      asm_out = dispatcher.dispatch("asm bar.cr:42")
      asm_out.should contain("Instructions for bar.cr:42")
      asm_out.should contain("0x00001000")
      asm_out.should contain("ret")
    end

    it "dispatches interleaved view command" do
      client = SpecFixtures.build_mock_with_handler { "" }
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)
      client.crystal.lines.reader.register_source("inter.cr", "def run\n  nop\nend")
      client.crystal.lines.map.add(0x2000_u64, "inter.cr", 2, 0, "nop", 1, "90", "run")

      # By function name
      view = dispatcher.dispatch("interleaved run")
      view.should contain("File: inter.cr")
      view.should contain("nop")

      # By address
      view_addr = dispatcher.dispatch("interleaved 0x2000")
      view_addr.should contain("File: inter.cr")
    end

    it "dispatches classes and methods inspection" do
      client = SpecFixtures.build_mock_with_handler do |cmd|
        if cmd == "isj"
          %([
            {"name": "*Player#score:Int32", "vaddr": 4096},
            {"name": "*Player#jump:Nil", "vaddr": 5000},
            {"name": "*Enemy#attack:Nil", "vaddr": 6000}
          ])
        else
          ""
        end
      end
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

      # Classes list
      classes_out = dispatcher.dispatch("classes")
      classes_out.should contain("Player")
      classes_out.should contain("Enemy")

      # Methods for class
      methods_out = dispatcher.dispatch("methods Player")
      methods_out.should contain("score:Int32")
      methods_out.should contain("jump:Nil")

      # Missing class arg
      dispatcher.dispatch("methods").should contain("Usage: crystal methods <class_name>")
    end

    it "dispatches runtime memory inspect commands for String, Array, Slice" do
      client = SpecFixtures.build_mock_with_handler do |cmd|
        case cmd
        when "pxj 4 @ 0x1000"
          "[1, 0, 0, 0]" # type_id 1
        when "pxj 4 @ 0x1004"
          "[13, 0, 0, 0]" # bytesize 13
        when "pxj 4 @ 0x1008"
          "[13, 0, 0, 0]" # length 13
        when "pxj 13 @ 0x100c"
          "[72, 101, 108, 108, 111, 32, 67, 114, 121, 115, 116, 97, 108]" # "Hello Crystal"
        when "pxj 4 @ 0x2000"
          "[2, 0, 0, 0]" # type_id 2
        when "pxj 4 @ 0x2004"
          "[10, 0, 0, 0]" # size 10
        when "pxj 4 @ 0x2008"
          "[16, 0, 0, 0]" # capacity 16
        when "pxj 8 @ 0x2010"
          "[0, 80, 0, 0, 0, 0, 0, 0]" # buffer 0x5000
        when "pxj 4 @ 0x3000"
          "[32, 0, 0, 0]" # size 32
        when "pxj 4 @ 0x3004"
          "[0, 0, 0, 0]" # read_only false
        when "pxj 8 @ 0x3008"
          "[0, 96, 0, 0, 0, 0, 0, 0]" # pointer 0x6000
        else
          ""
        end
      end
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

      # Inspect string
      str_out = dispatcher.dispatch("inspect string 0x1000")
      str_out.should contain("Crystal String @ 0x1000")
      str_out.should contain("Hello Crystal")

      # Inspect array
      arr_out = dispatcher.dispatch("inspect array 0x2000")
      arr_out.should contain("Crystal Array(T) @ 0x2000")

      # Inspect slice
      slice_out = dispatcher.dispatch("inspect slice 0x3000")
      slice_out.should contain("Crystal Slice(T) @ 0x3000")

      # Inspect missing type / usage
      dispatcher.dispatch("inspect").should contain("Usage: crystal inspect")
      dispatcher.dispatch("inspect unknown 0x1000").should contain("Unknown inspect type 'unknown'")
    end

    it "dispatches crash log parser command" do
      client = SpecFixtures.build_mock_with_handler do |cmd|
        if cmd == "CLj"
          %([{"file": "app.cr", "line": 25, "offset": 4096}])
        else
          ""
        end
      end
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)
      dispatcher.dispatch("crash").should contain("Crash / Debug Report")
    end
  end
end
