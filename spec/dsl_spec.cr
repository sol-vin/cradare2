require "./spec_helper"

describe Cradare2::DSL do
  describe Cradare2::DSL::Analysis do
    it "invokes analysis commands fluently and via block" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.analyze.all.calls.functions.preludes.emulate.consecutive
      mock.history.should contain("aaa")
      mock.history.should contain("aac")
      mock.history.should contain("aaf")
      mock.history.should contain("aap")
      mock.history.should contain("aae")
      mock.history.should contain("aat")

      client.analyze do |a|
        a.references
        a.autoname
      end
      mock.history.should contain("aar")
      mock.history.should contain("aan")
    end
  end

  describe Cradare2::DSL::Disassembly do
    it "disassembles text and functions" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("pd 10 @ 0x401000", "nop\nnop\n")
      mock.on("pdf @ 0x401000", "main function body")

      client.disasm.text(10, at: 0x401000).should eq("nop\nnop\n")
      client.disasm.function_text(0x401000).should eq("main function body")
    end

    it "decompiles via pdg or pdc" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("pdg @ 0x401000", "void main() { return; }")

      code = client.disasm.decompile(0x401000)
      code.should eq("void main() { return; }")
    end

    it "parses function_instructions from pdfj" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("pdfj @ 0x401000", "{\"ops\": [{\"addr\": 4198400, \"size\": 1, \"opcode\": \"nop\"}]}")

      ops = client.disasm.function_instructions(0x401000)
      ops.size.should eq(1)
      ops[0].opcode.should eq("nop")
      ops[0].offset.should eq(4198400)
    end
  end

  describe Cradare2::DSL::Memory do
    it "reads bytes, hex, strings, and multi-width integers" do
      client = SpecFixtures.build_mock_client
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("pxj 1 @ 0x401000", "[123]")
      mock.on("pxj 2 @ 0x401000", "[52, 18]") # 0x1234
      mock.on("pxj 8 @ 0x401000", "[1, 2, 3, 4, 5, 6, 7, 8]")
      mock.on("ps @ 0x401000", "Hello World")
      mock.on("px 16 @ 0x401000", "0x00401000  9090 ....")

      client.memory.read(0x401000, 4).should eq(Bytes[144, 144, 144, 144])
      client.memory.read_hex(0x401000, 4).should eq("90909090")
      client.memory.read_u8(0x401000).should eq(123_u8)
      client.memory.read_u16(0x401000).should eq(0x1234_u16)
      client.memory.read_u32(0x401000).should eq(0x90909090_u32)
      client.memory.read_u64(0x401000).should eq(0x0807060504030201_u64)
      client.memory.read_string(0x401000).should eq("Hello World")
      client.memory.hexdump(0x401000, size: 16).should contain("0x00401000")
    end

    it "writes bytes, strings, and integers" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.memory.write(0x401000, Bytes[0x90, 0xCC])
      mock.history.should contain("wx 90cc @ 0x401000")

      client.memory.write_string(0x401000, "testing")
      mock.history.should contain("w testing @ 0x401000")

      client.memory.write_u32(0x401000, 0x12345678_u32)
      mock.history.should contain("wv4 305419896 @ 0x401000")

      client.memory.write_u64(0x401000, 0x1122334455667788_u64)
      mock.history.should contain("wv8 1234605616436508552 @ 0x401000")
    end

    it "searches bytes and strings" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("/x 9090", "0x00401000 hit0_0\n0x00401050 hit0_1\n")
      mock.on("/ target", "0x00402000 hit_str\n")

      hits = client.memory.search_bytes(Bytes[0x90, 0x90])
      hits.should eq([0x401000_u64, 0x401050_u64])

      str_hits = client.memory.search_string("target")
      str_hits.should eq([0x402000_u64])
    end
  end

  describe Cradare2::DSL::Debugger do
    it "controls execution and breakpoints" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.debug do |d|
        d.breakpoint("main")
        d.step_until(0x401050)
        d.continue
        d.step
        d.step_over
        d.remove_breakpoint("main")
        d.clear_breakpoints
      end

      mock.history.should contain("db main")
      mock.history.should contain("dsu 0x401050")
      mock.history.should contain("dc")
      mock.history.should contain("ds")
      mock.history.should contain("dso")
      mock.history.should contain("db- main")
      mock.history.should contain("db-*")
    end

    it "manages registers, processes, and status" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("dp", "1234\n")
      mock.on("d?", "running\n")

      client.debug.set_register("rax", 0x1337_u64)
      mock.history.should contain("dr rax=0x1337")

      client.debug.pid.should eq(1234)
      client.debug.running?.should be_true
      client.debug.status.should eq("running")

      client.debug.attach(5678)
      mock.history.should contain("dp= 5678")

      client.debug.detach
      mock.history.should contain("dp-")

      client.debug.kill
      mock.history.should contain("dk 9")
    end

    it "generates demangled native crash diagnostic reports" do
      client = SpecFixtures.build_mock_client
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("fd @ 0x401032", "sym.*MyGame::Player#_process:Float64")

      report = client.debug.crash_report
      report.should contain("Native Crash Diagnostic Report")
      report.should contain("Crash PC (Instruction Pointer): 0x401032")
      report.should contain("Active Function: MyGame::Player#_process:Float64")
      report.should contain("game.dll")
      report.should contain("RAX:")
      report.should contain("Call Stack (Demangled):")
      report.should contain("#0 0x401032 in MyGame::Player#_process:Float64")
    end

    it "demangles backtrace symbols" do
      client = SpecFixtures.build_mock_client
      syms = client.debug.backtrace_symbols
      syms.should eq(["MyGame::Player#_process:Float64", "crystal_library_entry"])
    end
  end
end
