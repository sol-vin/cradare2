require "./spec_helper"

describe Cradare2::Model do
  describe Cradare2::Model::BinaryInfo do
    it "parses binary metadata correctly" do
      client = SpecFixtures.build_mock_client
      info = client.info
      info.arch.should eq("x86")
      info.bits.should eq(64)
      info.os.should eq("windows")
      info.format.should eq("pe")
      info.base_address.should eq(5368709120_u64)
      info.pic?.should be_true
      info.bits64?.should be_true
    end
  end

  describe Cradare2::Model::Function do
    it "parses analyzed functions list" do
      client = SpecFixtures.build_mock_client
      functions = client.functions
      functions.size.should eq(2)

      main_fn = functions[0]
      main_fn.name.should eq("sym.main")
      main_fn.offset.should eq(4198400)
      main_fn.size.should eq(128)
      main_fn.nargs.should eq(2)
      main_fn.nlocals.should eq(4)
      main_fn.stackframe.should eq(32)
      main_fn.signature.not_nil!.should contain("int main")

      entry_fn = functions[1]
      entry_fn.name.should eq("sym.crystal_library_entry")
      entry_fn.offset.should eq(4198528)
    end
  end

  describe Cradare2::Model::Symbol do
    it "parses symbols and exports" do
      client = SpecFixtures.build_mock_client
      symbols = client.symbols
      symbols.size.should eq(3)

      sym1 = symbols[0]
      sym1.name.should eq("sym.main")
      sym1.offset.should eq(4198400)
      sym1.function?.should be_true

      sym2 = symbols[1]
      sym2.display_name.should eq("MyGame::Player#_ready:Nil")

      exports = client.exports
      exports.size.should eq(1)
      exports[0].name.should eq("crystal_library_entry")
      exports[0].offset.should eq(4198528)

      imports = client.imports
      imports.size.should eq(2)
      imports[0].name.should eq("godot_string_new")
    end
  end

  describe Cradare2::Model::Section do
    it "parses sections and checks address bounds" do
      client = SpecFixtures.build_mock_client
      sections = client.sections
      sections.size.should eq(2)

      text_sec = sections[0]
      text_sec.name.should eq(".text")
      text_sec.vaddr.should eq(4198400)
      text_sec.size.should eq(32768)
      text_sec.executable?.should be_true
      text_sec.readable?.should be_true
      text_sec.writable?.should be_false

      text_sec.contains?(4198400).should be_true
      text_sec.contains?(4198500).should be_true
      text_sec.contains?(5000000).should be_false
    end
  end

  describe Cradare2::Model::StringItem do
    it "parses strings" do
      client = SpecFixtures.build_mock_client
      strings = client.strings
      strings.size.should eq(2)
      strings[0].string.should eq("Crystal Library Initialized")
      strings[0].offset.should eq(4231200)
      strings[1].string.should eq("Crystal Runtime Active")
    end
  end

  describe Cradare2::Model::Registers do
    it "parses registers and provides architecture-neutral helpers" do
      client = SpecFixtures.build_mock_client
      regs = client.debug.registers
      regs.rip.should eq(4198450)
      regs.pc.should eq(4198450)
      regs.rsp.should eq(140723423000)
      regs.sp.should eq(140723423000)
      regs.rbp.should eq(140723423048)
      regs.bp.should eq(140723423048)
      regs.rax.should eq(4198400)
      regs.rdx.should eq(4231168)
      regs["eflags"].should eq(514)
    end
  end

  describe Cradare2::Model::StackFrame do
    it "parses backtrace frames" do
      client = SpecFixtures.build_mock_client
      bt = client.debug.backtrace
      bt.size.should eq(2)
      bt[0].frame.should eq(0)
      bt[0].pc.should eq(4198450)
      bt[0].function.should eq("*MyGame::Player#_process:Float64")
      bt[1].pc.should eq(4198560)
    end
  end

  describe Cradare2::Model::MemoryMap do
    it "parses memory maps" do
      client = SpecFixtures.build_mock_client
      maps = client.debug.maps
      maps.size.should eq(2)
      maps[0].name.should eq("game.dll")
      maps[0].contains?(4198450).should be_true
      maps[0].executable?.should be_true
    end
  end

  describe Cradare2::Model::Instruction do
    it "parses instructions and to_s formatting" do
      client = SpecFixtures.build_mock_client
      instrs = client.disasm.instructions(2)
      instrs.size.should eq(2)
      instrs[0].offset.should eq(4198400)
      instrs[0].opcode.should eq("sub rsp, 0x28")
      instrs[0].to_s.should eq("sub rsp, 0x28")
      instrs[1].jump.should eq(4198912)
    end
  end

  describe Cradare2::Model::BasicBlock do
    it "parses basic block json" do
      json = "{\"addr\": 4198400, \"size\": 32, \"jump\": 4198432, \"fail\": 4198440, \"ninstrs\": 8}"
      bb = Cradare2::Model::BasicBlock.from_json(json)
      bb.offset.should eq(4198400)
      bb.size.should eq(32)
      bb.jump.should eq(4198432)
      bb.fail.should eq(4198440)
      bb.ninstrs.should eq(8)
    end
  end

  describe Cradare2::Model::Breakpoint do
    it "parses breakpoint json and checks properties" do
      json = "{\"addr\": 4198400, \"size\": 1, \"hw\": true, \"enabled\": true, \"hits\": 5}"
      bp = Cradare2::Model::Breakpoint.from_json(json)
      bp.offset.should eq(4198400)
      bp.enabled?.should be_true
      bp.hardware?.should be_true
      bp.hits.should eq(5)

      # Software breakpoint disabled with 0 hits
      json2 = "{\"addr\": 4200000, \"size\": 1, \"hw\": false, \"enabled\": false}"
      bp2 = Cradare2::Model::Breakpoint.from_json(json2)
      bp2.enabled?.should be_false
      bp2.hits.should be_nil
      bp2.hit_count.should eq(0)
    end
  end

  describe Cradare2::Model::Thread do
    it "parses thread json" do
      json = "{\"id\": 101, \"status\": \"running\", \"selected\": true, \"name\": \"MainThread\"}"
      th = Cradare2::Model::Thread.from_json(json)
      th.id.should eq(101)
      th.status.should eq("running")
      th.selected?.should be_true
      th.name.should eq("MainThread")
    end
  end

  describe "Architecture-neutral register fallbacks" do
    it "handles 32-bit x86 register sets (eip, esp, ebp, eax)" do
      json = "{\"eip\": 4198400, \"esp\": 2147483640, \"ebp\": 2147483648, \"eax\": 100, \"ebx\": 200}"
      regs = Cradare2::Model::Registers.from_json(json)
      regs.pc.should eq(4198400_u64)
      regs.sp.should eq(2147483640_u64)
      regs.bp.should eq(2147483648_u64)
      regs.rax.should eq(100_u64)
      regs.rbx.should eq(200_u64)
    end

    it "handles ARM64 register sets (pc, sp, x0, x1)" do
      json = "{\"pc\": 8388608, \"sp\": 140723423000, \"x0\": 42, \"x1\": 99}"
      regs = Cradare2::Model::Registers.from_json(json)
      regs.pc.should eq(8388608_u64)
      regs.sp.should eq(140723423000_u64)
      regs.rax.should eq(42_u64) # x0 maps to rax fallback
      regs.rbx.should eq(99_u64) # x1 maps to rbx fallback
    end
  end

  describe "MemoryMap permissions" do
    it "accurately detects read, write, and execute flags" do
      m1 = Cradare2::Model::MemoryMap.from_json("{\"name\":\"code\",\"from\":4096,\"to\":8192,\"perm\":\"r-x\"}")
      m1.readable?.should be_true
      m1.writable?.should be_false
      m1.executable?.should be_true

      m2 = Cradare2::Model::MemoryMap.from_json("{\"name\":\"data\",\"from\":8192,\"to\":16384,\"perm\":\"rw-\"}")
      m2.readable?.should be_true
      m2.writable?.should be_true
      m2.executable?.should be_false

      m3 = Cradare2::Model::MemoryMap.from_json("{\"name\":\"guard\",\"from\":16384,\"to\":20480,\"perm\":\"---\"}")
      m3.readable?.should be_false
      m3.writable?.should be_false
      m3.executable?.should be_false
    end
  end
end
