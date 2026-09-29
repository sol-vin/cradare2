require "./spec_helper"

describe Cradare2::CrystalHelper do
  describe "Crystal binary detection" do
    it "detects Crystal binary when __crystal_main is present in symbols" do
      client = SpecFixtures.build_mock_with_handler do |cmd|
        case cmd
        when "isj"
          %([{"name":"sym.__crystal_main","vaddr":4198400,"size":100}])
        when "aflj"
          "[]"
        else
          ""
        end
      end

      client.crystal.crystal_binary?.should be_true
      client.crystal.entrypoint.should eq(4198400_u64)
    end

    it "detects Crystal binary when Boehm GC symbols are present" do
      client = SpecFixtures.build_mock_with_handler do |cmd|
        case cmd
        when "isj"
          %([{"name":"sym.imp.GC_init","vaddr":4199000,"size":20},{"name":"sym.imp.GC_malloc","vaddr":4199050,"size":30}])
        when "aflj"
          "[]"
        else
          ""
        end
      end

      client.crystal.crystal_binary?.should be_true
      gc_syms = client.crystal.gc_symbols
      gc_syms.size.should eq(2)
      gc_syms.map(&.name).should contain("sym.imp.GC_init")
      gc_syms.map(&.name).should contain("sym.imp.GC_malloc")
    end

    it "returns false for generic non-Crystal binary" do
      client = SpecFixtures.build_mock_with_handler do |cmd|
        case cmd
        when "isj"
          %([{"name":"sym.main","vaddr":4194304,"size":50}])
        when "aflj"
          %([{"offset":4194304,"name":"main","size":50,"realsz":50,"cc":1,"nbbs":1,"edges":0,"ebbs":1,"minbound":4194304,"maxbound":4194354,"calltype":"","difftype":"","nargs":2,"nlocals":0}])
        else
          ""
        end
      end

      client.crystal.crystal_binary?.should be_false
    end
  end

  describe "symbol and class parsing" do
    it "parses symbol components correctly" do
      client = Cradare2.mock

      info1 = client.crystal.parse_symbol("sym.*~String#bytesize:Int32")
      info1.class_name.should eq("String")
      info1.method_name.should eq("bytesize:Int32")
      info1.is_instance_method.should be_true

      info2 = client.crystal.parse_symbol("sym.*~Array(Int32)#push<Int32>:Array(Int32)")
      info2.class_name.should eq("Array(Int32)")
      info2.method_name.should eq("push<Int32>:Array(Int32)")
      info2.is_instance_method.should be_true

      info3 = client.crystal.parse_symbol("sym.*Crystal::main:Int32")
      info3.class_name.should eq("Crystal")
      info3.method_name.should eq("main:Int32")
      info3.is_instance_method.should be_false

      info4 = client.crystal.parse_symbol("sym.main")
      info4.class_name.should be_nil
      info4.method_name.should be_nil
    end

    it "discovers classes and filters methods" do
      client = SpecFixtures.build_mock_with_handler do |cmd|
        case cmd
        when "aflj"
          %([
            {"offset":4198400,"name":"sym.*~String#bytesize:Int32","size":20,"realsz":20,"cc":1,"nbbs":1,"edges":0,"ebbs":1,"minbound":4198400,"maxbound":4198420,"calltype":"","difftype":"","nargs":1,"nlocals":0},
            {"offset":4198450,"name":"sym.*~String#to_slice:Slice(UInt8)","size":30,"realsz":30,"cc":1,"nbbs":1,"edges":0,"ebbs":1,"minbound":4198450,"maxbound":4198480,"calltype":"","difftype":"","nargs":1,"nlocals":0},
            {"offset":4198500,"name":"sym.*~Player#score:Int32","size":15,"realsz":15,"cc":1,"nbbs":1,"edges":0,"ebbs":1,"minbound":4198500,"maxbound":4198515,"calltype":"","difftype":"","nargs":1,"nlocals":0}
          ])
        when "isj"
          %([
            {"name":"sym.*~String#bytesize:Int32","vaddr":4198400,"size":20},
            {"name":"sym.*~Enemy#health:Int32","vaddr":4198600,"size":10}
          ])
        else
          ""
        end
      end

      classes = client.crystal.classes
      classes.should contain("String")
      classes.should contain("Player")
      classes.should contain("Enemy")

      string_methods = client.crystal.methods_for_class("String")
      string_methods.size.should eq(2)
      string_methods.map(&.name).should contain("sym.*~String#bytesize:Int32")
      string_methods.map(&.name).should contain("sym.*~String#to_slice:Slice(UInt8)")

      enemy_symbols = client.crystal.symbols_for_class("Enemy")
      enemy_symbols.size.should eq(1)
      enemy_symbols.first.name.should eq("sym.*~Enemy#health:Int32")
    end
  end

  describe "memory layout inspection" do
    it "reads a Crystal String from memory" do
      # Target string "Hello, Crystal!" (15 bytes)
      # Layout:
      # Offset 0: type_id = 42
      # Offset 4: bytesize = 15
      # Offset 8: length = 15
      # Offset 12: "Hello, Crystal!"
      client = SpecFixtures.build_mock_with_handler do |cmd|
        case cmd
        when "pxj 4 @ 0x1000"
          "[42, 0, 0, 0]"
        when "pxj 4 @ 0x1004"
          "[15, 0, 0, 0]"
        when "pxj 4 @ 0x1008"
          "[15, 0, 0, 0]"
        when "pxj 15 @ 0x100c"
          "[72, 101, 108, 108, 111, 44, 32, 67, 114, 121, 115, 116, 97, 108, 33]"
        else
          ""
        end
      end

      str_obj = client.crystal.read_string(0x1000_u64)
      str_obj.address.should eq(0x1000_u64)
      str_obj.type_id.should eq(42)
      str_obj.bytesize.should eq(15)
      str_obj.length.should eq(15)
      str_obj.value.should eq("Hello, Crystal!")

      # Also test convenience method
      client.crystal.read_string_value(0x1000_u64).should eq("Hello, Crystal!")
    end

    it "reads a Crystal Array header from memory" do
      # Array(Int32) header at 0x2000
      # Offset 0: type_id = 99
      # Offset 4: size = 5
      # Offset 8: capacity = 8
      # Offset 16: buffer pointer = 0x3000
      client = SpecFixtures.build_mock_with_handler do |cmd|
        case cmd
        when "pxj 4 @ 0x2000"
          "[99, 0, 0, 0]"
        when "pxj 4 @ 0x2004"
          "[5, 0, 0, 0]"
        when "pxj 4 @ 0x2008"
          "[8, 0, 0, 0]"
        when "pxj 8 @ 0x2010"
          "[0, 48, 0, 0, 0, 0, 0, 0]" # 0x3000
        else
          ""
        end
      end

      arr = client.crystal.read_array_header(0x2000_u64)
      arr.address.should eq(0x2000_u64)
      arr.type_id.should eq(99)
      arr.size.should eq(5)
      arr.capacity.should eq(8)
      arr.buffer_address.should eq(0x3000_u64)
    end

    it "reads a Crystal Slice header from memory" do
      # Slice(UInt8) at 0x4000
      # Offset 0: size = 64
      # Offset 4: read_only = 1 (UInt8)
      # Offset 8: pointer = 0x5000
      client = SpecFixtures.build_mock_with_handler do |cmd|
        case cmd
        when "pxj 4 @ 0x4000"
          "[64, 0, 0, 0]"
        when "pxj 1 @ 0x4004"
          "[1]"
        when "pxj 8 @ 0x4008"
          "[0, 80, 0, 0, 0, 0, 0, 0]" # 0x5000
        else
          ""
        end
      end

      slice = client.crystal.read_slice_header(0x4000_u64)
      slice.address.should eq(0x4000_u64)
      slice.size.should eq(64)
      slice.read_only.should be_true
      slice.pointer_address.should eq(0x5000_u64)
    end

    it "handles zero-length or negative bytesize gracefully in read_string" do
      client = SpecFixtures.build_mock_with_handler do |cmd|
        case cmd
        when "pxj 4 @ 0x1000"
          "[10, 0, 0, 0]"
        when "pxj 4 @ 0x1004"
          "[255, 255, 255, 255]" # -1 in 2's complement
        when "pxj 4 @ 0x1008"
          "[0, 0, 0, 0]"
        else
          ""
        end
      end

      str_obj = client.crystal.read_string(0x1000_u64)
      str_obj.value.should eq("")
      str_obj.bytesize.should eq(-1)
    end
  end

  describe "demangled backtrace & crash report" do
    it "formats a demangled backtrace and comprehensive crash report" do
      client = SpecFixtures.build_mock_with_handler do |cmd|
        case cmd
        when "ij"
          %({"bin":{"arch":"x86","bits":64,"os":"windows","bintype":"pe","endian":"little"},"core":{"file":"game.exe"}})
        when "drj"
          %({"rip":4198400,"rsp":140737488347136,"rax":42,"rbx":0,"rcx":100,"rdx":200})
        when "dbtj"
          %([
            {"frame":0,"addr":4198400,"size":32,"fname":"sym.*~Player#take_damage<Int32>:Nil"},
            {"frame":1,"addr":4199000,"size":64,"fname":"sym.*~Game#update:Nil"},
            {"frame":2,"addr":4200000,"size":48,"fname":"sym.__crystal_main"}
          ])
        when "pdfj @ 0x401000", "pdj 1 @ 0x401000"
          %([{"offset":4198400,"size":3,"opcode":"mov rax, rcx","bytes":"4889c8"}])
        else
          ""
        end
      end

      bt = client.crystal.demangled_backtrace
      bt.size.should eq(3)
      bt[0].function_name.should eq("Player#take_damage<Int32>:Nil")
      bt[1].function_name.should eq("Game#update:Nil")
      bt[2].function_name.should eq("__crystal_main")

      report = client.crystal.crash_report
      report.should contain("# Crystal Target Crash / Debug Report")
      report.should contain("Architecture: x86 (64-bit, little endian)")
      report.should contain("RIP / PC : 0x401000")
      report.should contain("mov rax, rcx")
      report.should contain("Player#take_damage<Int32>:Nil")
      report.should contain("Game#update:Nil")
    end
  end

  describe "block syntax DSL" do
    it "yields crystal helper in client.crystal block" do
      client = SpecFixtures.build_mock_with_handler do |cmd|
        cmd == "isj" ? %([{"name":"sym.__crystal_main","vaddr":4198400,"size":100}]) : ""
      end

      yielded = false
      client.crystal do |c|
        yielded = true
        c.crystal_binary?.should be_true
      end
      yielded.should be_true
    end
  end
end
