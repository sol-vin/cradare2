require "./spec_helper"
require "../src/cradare2/plugin/dispatcher"

describe Cradare2::Plugin::CommandDispatcher do
  it "returns help text on help command or empty input" do
    client = Cradare2.mock
    dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

    dispatcher.dispatch("help").should contain("Usage: crystal <command>")
    dispatcher.dispatch("?").should contain("Usage: crystal <command>")
    dispatcher.dispatch("").should contain("Usage: crystal <command>")
    dispatcher.dispatch("crystal help").should contain("Usage: crystal <command>")
  end

  it "handles crystal detect command" do
    # When binary is Crystal
    client_cr = SpecFixtures.build_mock_with_handler do |cmd|
      cmd == "isj" ? %([{"name":"sym.__crystal_main","vaddr":4198400,"size":50}]) : "[]"
    end
    disp_cr = Cradare2::Plugin::CommandDispatcher.new(client_cr)
    out1 = disp_cr.dispatch("detect")
    out1.should contain("Target is a Crystal binary!")
    out1.should contain("0x401000")

    # When binary is not Crystal
    client_non = SpecFixtures.build_mock_with_handler { |_| "[]" }
    disp_non = Cradare2::Plugin::CommandDispatcher.new(client_non)
    disp_non.dispatch("detect").should contain("Target does NOT appear to be a Crystal binary.")
  end

  it "handles crystal info command" do
    client = SpecFixtures.build_mock_with_handler do |cmd|
      case cmd
      when "isj"
        %([{"name":"sym.__crystal_main","vaddr":4198400,"size":50},{"name":"sym.imp.GC_init","vaddr":4199000,"size":20}])
      when "aflj"
        "[]"
      else
        ""
      end
    end

    disp = Cradare2::Plugin::CommandDispatcher.new(client)
    info_out = disp.dispatch("info")
    info_out.should contain("=== Crystal Target Info ===")
    info_out.should contain("Crystal Binary: Yes")
    info_out.should contain("Entrypoint (__crystal_main): 0x401000")
    info_out.should contain("Boehm GC Functions")
  end

  it "handles crystal demangle command" do
    client = Cradare2.mock
    disp = Cradare2::Plugin::CommandDispatcher.new(client)

    # Missing argument
    disp.dispatch("demangle").should contain("Usage: crystal demangle <symbol>")

    # Standard demangle
    res = disp.dispatch("demangle *Foo::Bar#baz:Int32")
    res.should contain("Foo::Bar#baz:Int32")

    # PDB escape demangle
    res_pdb = disp.dispatch("demangle pdb._2A.add.3C.Int32.2C..20.Int32.3E..3A.Int32")
    res_pdb.should contain("add<Int32, Int32>:Int32")
  end

  it "handles crystal demangle-all command and sends afn / fr to r2" do
    executed = [] of String
    client = SpecFixtures.build_mock_with_handler do |cmd|
      executed << cmd
      case cmd
      when "aflj"
        %([{"offset":4198400,"name":"pdb._2A.add.3C.Int32.3E..3A.Int32","size":20,"realsz":20,"cc":1,"nbbs":1,"edges":0,"ebbs":1,"minbound":4198400,"maxbound":4198420,"calltype":"","difftype":"","nargs":1,"nlocals":0}])
      when "isj"
        "[]"
      else
        ""
      end
    end

    disp = Cradare2::Plugin::CommandDispatcher.new(client)
    res = disp.dispatch("demangle-all")
    res.should contain("Demangled and renamed 1 functions/symbols")

    # Verify afn was called with safe demangled name
    executed.any? { |c| c.starts_with?("afn") && c.includes?("add<Int32>:Int32") }.should be_true
  end

  it "handles crystal lines sync command" do
    executed = [] of String
    client = SpecFixtures.build_mock_with_handler do |cmd|
      executed << cmd
      ""
    end

    disp = Cradare2::Plugin::CommandDispatcher.new(client)
    # Pre-add line
    client.crystal.lines.map.add(0x401000_u64, "calc.cr", 1, 0, "nop", 1, source_text: "x = 1")

    res = disp.dispatch("lines sync")
    res.should contain("Synchronized 1 source line mappings")
    executed.should contain("CL 0x401000 calc.cr:1")
  end

  it "handles crystal lines <addr> command" do
    client = Cradare2.mock
    disp = Cradare2::Plugin::CommandDispatcher.new(client)
    client.crystal.lines.map.add(0x401020_u64, "player.cr", 15, 2, "ret", 1, source_text: "return @health")

    # Existing address
    out_mapped = disp.dispatch("lines 0x401020")
    out_mapped.should contain("player.cr:15")
    out_mapped.should contain("return @health")

    # Unmapped address
    out_unmapped = disp.dispatch("lines 0x999999")
    out_unmapped.should contain("No source mapping found for address 0x999999")
  end

  it "handles crystal src command" do
    client = Cradare2.mock
    disp = Cradare2::Plugin::CommandDispatcher.new(client)

    # Missing arg
    disp.dispatch("src").should contain("Usage: crystal src <addr>")

    # Invalid address
    disp.dispatch("src invalid_hex").should contain("Invalid address")

    # Unmapped address
    disp.dispatch("src 0x555555").should contain("No source mapping found")

    # Mapped address with source context
    client.crystal.lines.reader.register_source("game.cr", "def start\n  init_window\n  run_loop\nend")
    client.crystal.lines.map.add(0x401000_u64, "game.cr", 2, 0, "call init", 5)

    out_src = disp.dispatch("src 0x401000")
    out_src.should contain("=== game.cr:2 (0x401000) ===")
    out_src.should contain("def start")
    out_src.should contain("init_window")
    out_src.should contain("run_loop")
    out_src.should contain("▶")
  end

  it "handles crystal asm command" do
    client = Cradare2.mock
    disp = Cradare2::Plugin::CommandDispatcher.new(client)

    # Missing arg
    disp.dispatch("asm").should contain("Usage: crystal asm <file:line>")

    # Invalid format
    disp.dispatch("asm invalid_spec").should contain("Invalid format")

    # Invalid line number
    disp.dispatch("asm file.cr:abc").should contain("Invalid line number")

    # No instructions mapped
    disp.dispatch("asm file.cr:10").should contain("No instructions found")

    # Mapped instructions
    client.crystal.lines.map.add(0x401000_u64, "app.cr", 5, 0, "mov eax, 1", 5, "b801000000")
    client.crystal.lines.map.add(0x401005_u64, "app.cr", 5, 0, "ret", 1, "c3")

    out_asm = disp.dispatch("asm app.cr:5")
    out_asm.should contain("Instructions for app.cr:5 (2 insts)")
    out_asm.should contain("0x00401000")
    out_asm.should contain("mov eax, 1")
    out_asm.should contain("0x00401005")
    out_asm.should contain("ret")
  end

  it "handles crystal inspect commands for string, array, and slice" do
    client = SpecFixtures.build_mock_with_handler do |cmd|
      case cmd
      # String at 0x1000: type_id 1, bytesize 5, len 5, "Hello"
      when "pxj 4 @ 0x1000" then "[1, 0, 0, 0]"
      when "pxj 4 @ 0x1004" then "[5, 0, 0, 0]"
      when "pxj 4 @ 0x1008" then "[5, 0, 0, 0]"
      when "pxj 5 @ 0x100c" then "[72, 101, 108, 108, 111]"
        # Array at 0x2000: type_id 2, size 3, cap 4, buffer 0x3000
      when "pxj 4 @ 0x2000" then "[2, 0, 0, 0]"
      when "pxj 4 @ 0x2004" then "[3, 0, 0, 0]"
      when "pxj 4 @ 0x2008" then "[4, 0, 0, 0]"
      when "pxj 8 @ 0x2010" then "[0, 48, 0, 0, 0, 0, 0, 0]" # 0x3000
      # Slice at 0x4000: size 8, ro 1, ptr 0x5000
      when "pxj 4 @ 0x4000" then "[8, 0, 0, 0]"
      when "pxj 1 @ 0x4004" then "[1]"
      when "pxj 8 @ 0x4008" then "[0, 80, 0, 0, 0, 0, 0, 0]" # 0x5000
      else                       ""
      end
    end

    disp = Cradare2::Plugin::CommandDispatcher.new(client)

    # String inspection
    out_str = disp.dispatch("inspect string 0x1000")
    out_str.should contain("Crystal String @ 0x1000")
    out_str.should contain("type_id:  1")
    out_str.should contain("bytesize: 5")
    out_str.should contain("value:    \"Hello\"")

    # Array inspection
    out_arr = disp.dispatch("inspect array 0x2000")
    out_arr.should contain("Crystal Array(T) @ 0x2000")
    out_arr.should contain("size:     3")
    out_arr.should contain("capacity: 4")
    out_arr.should contain("buffer:   0x3000")

    # Slice inspection
    out_slice = disp.dispatch("inspect slice 0x4000")
    out_slice.should contain("Crystal Slice(T) @ 0x4000")
    out_slice.should contain("size:      8")
    out_slice.should contain("read_only: true")
    out_slice.should contain("pointer:   0x5000")

    # Unknown type
    disp.dispatch("inspect tuple 0x1000").should contain("Unknown inspect type 'tuple'")

    # Missing args
    disp.dispatch("inspect").should contain("Usage: crystal inspect")
  end

  it "handles classes and methods commands" do
    client = SpecFixtures.build_mock_with_handler do |cmd|
      case cmd
      when "aflj"
        %([
          {"offset":4198400,"name":"*~Player#jump:Nil","size":20,"realsz":20,"cc":1,"nbbs":1,"edges":0,"ebbs":1,"minbound":4198400,"maxbound":4198420,"calltype":"","difftype":"","nargs":1,"nlocals":0},
          {"offset":4198500,"name":"*~Player#attack:Nil","size":30,"realsz":30,"cc":1,"nbbs":1,"edges":0,"ebbs":1,"minbound":4198500,"maxbound":4198530,"calltype":"","difftype":"","nargs":1,"nlocals":0}
        ])
      when "isj"
        "[]"
      else
        ""
      end
    end

    disp = Cradare2::Plugin::CommandDispatcher.new(client)

    # Classes list
    out_cls = disp.dispatch("classes")
    out_cls.should contain("Discovered Crystal Classes/Modules")
    out_cls.should contain("Player")

    # Methods for class
    out_meth = disp.dispatch("methods Player")
    out_meth.should contain("Methods for Player (2)")
    out_meth.should contain("Player#jump:Nil")
    out_meth.should contain("Player#attack:Nil")

    # Missing class arg
    disp.dispatch("methods").should contain("Usage: crystal methods <class_name>")
  end

  it "reports unknown subcommands gracefully" do
    client = Cradare2.mock
    disp = Cradare2::Plugin::CommandDispatcher.new(client)
    disp.dispatch("foobar").should contain("Unknown crystal command: 'foobar'")
  end
end
