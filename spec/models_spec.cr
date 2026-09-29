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

      lapis_fn = functions[1]
      lapis_fn.name.should eq("sym.lapis_gdextension_entry")
      lapis_fn.offset.should eq(4198528)
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
      exports[0].name.should eq("lapis_gdextension_entry")
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
      strings[0].string.should eq("Godot Engine Initialized")
      strings[0].offset.should eq(4231200)
      strings[1].string.should eq("Lapis Runtime Active")
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
end
