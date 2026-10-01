require "./spec_helper"
require "../src/cradare2/plugin/dispatcher"

describe "Crystal Plugin Stress & Extreme Edge Case Suite" do
  before_each do
    Cradare2::Util::Demangler.clear_cache
  end

  describe "1. Demangler Deep Generics & Stress Combinations" do
    it "demangles 200 variations of deeply nested generic hierarchies" do
      types = ["Int32", "String", "Float64", "Bool", "UInt8", "Char"]
      containers = ["Array", "Slice", "Hash", "Tuple", "NamedTuple", "Set", "Channel", "Pointer"]

      count = 0
      containers.each do |c1|
        containers.each do |c2|
          types.each do |t|
            count += 1
            break if count > 200
            # Construct a symbol: *Container1(Container2(Type))#process:Nil
            raw_sym = "*#{c1}(#{c2}(#{t}))#process:Nil"
            demangled = Cradare2::Util::Demangler.demangle(raw_sym)
            demangled.should eq("#{c1}(#{c2}(#{t}))#process:Nil")

            # Test method parsing
            parsed = Cradare2::Util::Demangler.parse_crystal_method(demangled)
            parsed.should_not be_nil
            parsed.not_nil![0].should eq("#{c1}(#{c2}(#{t}))")
            parsed.not_nil![1].should eq("process:Nil")
            parsed.not_nil![2].should be_true
          end
        end
      end
    end

    it "handles union types with 5 or more variants" do
      sym = "*MyUnionHandler#process:(Int32 | String | Float64 | Bool | Nil)"
      demangled = Cradare2::Util::Demangler.demangle(sym)
      demangled.should eq("MyUnionHandler#process:(Int32 | String | Float64 | Bool | Nil)")
    end

    it "handles proc types with multiple arguments and return types" do
      sym = "*Async#spawn:(Proc(Int32, String, Float64, Bool))"
      demangled = Cradare2::Util::Demangler.demangle(sym)
      demangled.should eq("Async#spawn:(Proc(Int32, String, Float64, Bool))")
    end

    it "handles PDB symbols containing complex operator overloads on generic classes" do
      # Array(Int32)#[]=(Int32, Int32):Int32
      # _2A. -> *, .28. -> (, .29. -> ), .23. -> #, .5B..5D..3D. -> []=, .3C. -> <, .2C. -> ,, .20. -> ' ', .3E. -> >, .3A. -> :
      pdb_op = "pdb._2A.Array.28.Int32.29..23..5B..5D..3D..3C.Int32.2C..20.Int32.3E..3A.Int32"
      demangled = Cradare2::Util::Demangler.demangle(pdb_op)
      demangled.should eq("Array(Int32)#[]=<Int32, Int32>:Int32")
    end

    it "handles PDB symbols with triple equality ===" do
      pdb_triple = "pdb._2A.Regex.23..3D..3D..3D..3C.String.3E..3A.Bool"
      Cradare2::Util::Demangler.demangle(pdb_triple).should eq("Regex#===<String>:Bool")
    end

    it "handles PDB symbols with pattern match =~ and !~" do
      pdb_match = "pdb._2A.String.23..3D..7E..3C.Regex.3E..3A..28.Int32.20..7C..20.Nil.29."
      Cradare2::Util::Demangler.demangle(pdb_match).should eq("String#=~<Regex>:(Int32 | Nil)")

      pdb_not_match = "pdb._2A.String.23..21..7E..3C.Regex.3E..3A.Bool"
      Cradare2::Util::Demangler.demangle(pdb_not_match).should eq("String#!~<Regex>:Bool")
    end

    it "handles PDB symbols with wrapping arithmetic operators &+, &-, &*" do
      pdb_wrap_add = "pdb._2A.Int32.23..26..2B..3C.Int32.3E..3A.Int32"
      Cradare2::Util::Demangler.demangle(pdb_wrap_add).should eq("Int32#&+<Int32>:Int32")

      pdb_wrap_sub = "pdb._2A.Int32.23..26..2D..3C.Int32.3E..3A.Int32"
      Cradare2::Util::Demangler.demangle(pdb_wrap_sub).should eq("Int32#&-<Int32>:Int32")

      pdb_wrap_mul = "pdb._2A.Int32.23..26._2A..3C.Int32.3E..3A.Int32"
      Cradare2::Util::Demangler.demangle(pdb_wrap_mul).should eq("Int32#&*<Int32>:Int32")
    end

    it "demangles 1000 symbols in under 50ms with caching" do
      symbols = (1..1000).map do |i|
        "pdb._2A.PerformanceTestModule#{i % 20}.3A..3A.Class#{i}.23.run_task.3C.Int32.3E..3A.Nil"
      end

      # Warm-up / fill cache
      symbols.each { |s| Cradare2::Util::Demangler.demangle(s) }

      start_time = Time.instant
      symbols.each do |s|
        Cradare2::Util::Demangler.demangle(s)
      end
      elapsed = Time.instant - start_time
      # 1000 cache hits should be nearly instantaneous (< 50ms)
      elapsed.total_milliseconds.should be < 50.0
    end
  end

  describe "2. Source Map Scale & High Density Range Queries" do
    it "handles 5,000 instruction mappings across 25 simulated files" do
      reader = Cradare2::Lines::SourceReader.new
      25.times do |f_idx|
        filename = "src/module_#{f_idx}/service.cr"
        content = (1..200).map { |line_num| "line_code_#{line_num} = #{line_num}" }.join("\n")
        reader.register_source(filename, content)
      end

      map = Cradare2::Lines::SourceMap.new(reader)
      base_addr = 0x10000_u64

      # Populate 5000 instructions
      current_addr = base_addr
      25.times do |f_idx|
        filename = "src/module_#{f_idx}/service.cr"
        (1..100).each do |line_num|
          # 2 instructions per line
          map.add(current_addr, filename, line_num, 0, "mov eax, #{line_num}", 5, "b800000000", "mod_#{f_idx}_func")
          current_addr += 5
          map.add(current_addr, filename, line_num, 0, "add eax, 1", 3, "83c001", "mod_#{f_idx}_func")
          current_addr += 3
        end
      end

      map.size.should eq(5000)
      map.files.size.should eq(25)

      # Test precise address lookups
      loc1 = map.find_by_address(base_addr)
      loc1.should_not be_nil
      loc1.not_nil!.file.should eq("src/module_0/service.cr")
      loc1.not_nil!.line.should eq(1)

      # Test interior instruction lookup
      ins_interior = map.find_instruction_containing(base_addr + 2)
      ins_interior.should_not be_nil
      ins_interior.not_nil!.address.should eq(base_addr)

      # Test line to instructions lookup
      line_ins = map.find_by_line("src/module_0/service.cr", 1)
      line_ins.size.should eq(2)
      line_ins[0].address.should eq(base_addr)
      line_ins[1].address.should eq(base_addr + 5)

      # Test grouping by function name
      groups = map.groups_for_function_name("mod_0_func")
      groups.size.should eq(100)
      groups.first.line.should eq(1)
      groups.first.count.should eq(2)
      groups.last.line.should eq(100)
    end

    it "handles variable length x86_64 instructions accurately (1 to 15 bytes)" do
      map = Cradare2::Lines::SourceMap.new
      base = 0x20000_u64
      sizes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

      curr = base
      sizes.each_with_index do |sz, idx|
        map.add(curr, "variable_len.cr", idx + 1, 0, "inst_size_#{sz}", sz)
        curr += sz
      end

      # Check each instruction boundary
      curr = base
      sizes.each_with_index do |sz, idx|
        # Start of instruction
        map.find_instruction_containing(curr).should_not be_nil
        map.find_instruction_containing(curr).not_nil!.address.should eq(curr)
        map.find_instruction_containing(curr).not_nil!.size.should eq(sz)

        # Middle of instruction (if sz > 1)
        if sz > 1
          map.find_instruction_containing(curr + (sz // 2)).should_not be_nil
          map.find_instruction_containing(curr + (sz // 2)).not_nil!.address.should eq(curr)
        end

        # End byte of instruction
        map.find_instruction_containing(curr + sz - 1).should_not be_nil
        map.find_instruction_containing(curr + sz - 1).not_nil!.address.should eq(curr)

        curr += sz
      end

      # Beyond all instructions
      map.find_instruction_containing(curr).should be_nil
    end
  end

  describe "3. Source Reader Unicode & Large File Support" do
    it "handles UTF-8 source code with multi-byte characters and emojis" do
      reader = Cradare2::Lines::SourceReader.new
      utf8_code = <<-'CRYSTAL'
      # 🚀 Crystal Unicode Test
      def こんにちは(名前 : String)
        puts "こんにちは, #{名前}! 🌟"
      end
      CRYSTAL

      reader.register_source("japanese.cr", utf8_code)
      reader.line_count("japanese.cr").should eq(4)
      reader.read_line("japanese.cr", 1).not_nil!.should contain("🚀 Crystal Unicode Test")
      reader.read_line("japanese.cr", 2).not_nil!.should contain("こんにちは")
      reader.read_line("japanese.cr", 3).not_nil!.should contain("🌟")
    end

    it "reads efficiently from simulated 5,000 line source file" do
      reader = Cradare2::Lines::SourceReader.new
      lines = (1..5000).map { |i| "def method_#{i}; #{i} * 2; end" }
      reader.register_source("large.cr", lines.join("\n"))

      reader.line_count("large.cr").should eq(5000)
      reader.read_line("large.cr", 2500).should eq("def method_2500; 2500 * 2; end")
      reader.read_line("large.cr", 5000).should eq("def method_5000; 5000 * 2; end")

      ctx = reader.read_context("large.cr", 2500, window: 5)
      ctx.size.should eq(11)
      ctx.first[:line].should eq(2495)
      ctx.last[:line].should eq(2505)
    end
  end

  describe "4. Command Dispatcher Extreme Input & Argument Variants" do
    it "handles excessive whitespace, tabs, and mixed casing gracefully" do
      client = SpecFixtures.build_mock_with_handler { "" }
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

      # Mixed case with extra spaces
      dispatcher.dispatch("   CRYSTAL   HELP   ").should contain("Usage: crystal <command>")
      dispatcher.dispatch("\t\tcrystal\t\thelp\t\t").should contain("Usage: crystal <command>")
      dispatcher.dispatch("  demangle   pdb._2A.test.3A.Nil  ").should contain("test:Nil")
    end

    it "handles rapid repeated dispatch commands without state contamination" do
      client = SpecFixtures.build_mock_with_handler { "" }
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

      100.times do |i|
        res = dispatcher.dispatch("demangle pdb._2A.Worker#{i}.23.perform.3A.Nil")
        res.should contain("Worker#{i}#perform:Nil")
      end
    end

    it "safely handles null bytes and control characters in command strings" do
      client = SpecFixtures.build_mock_with_handler { "" }
      dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

      # Should not crash on strange or malformed inputs
      res = dispatcher.dispatch("demangle \u0000")
      res.should_not be_nil
    end
  end
end
