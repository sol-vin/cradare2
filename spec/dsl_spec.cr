require "./spec_helper"

describe Cradare2::DSL do
  describe Cradare2::DSL::Analysis do
    it "invokes analysis commands fluently and via block" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.analyze.all.calls.functions
      mock.history.should contain("aaa")
      mock.history.should contain("aac")
      mock.history.should contain("aaf")

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
      mock.on("pdf @ main", "main function body")

      client.disasm.text(10, at: 0x401000).should eq("nop\nnop\n")
      client.disasm.function_text("main").should eq("main function body")
    end
  end

  describe Cradare2::DSL::Memory do
    it "reads bytes and integers" do
      client = SpecFixtures.build_mock_client
      bytes = client.memory.read(0x401000, 4)
      bytes.should eq(Bytes[144, 144, 144, 144])

      hex = client.memory.read_hex(0x401000, 4)
      hex.should eq("90909090")

      val = client.memory.read_u32(0x401000)
      val.should eq(0x90909090_u32)
    end

    it "writes bytes and integers" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.memory.write(0x401000, Bytes[0x90, 0xCC])
      mock.history.should contain("wx 90cc @ 0x401000")

      client.memory.write_u32(0x401000, 0x12345678_u32)
      mock.history.should contain("wv4 305419896 @ 0x401000")
    end

    it "parses search offsets" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("/x 9090", "0x00401000 hit0_0\n0x00401050 hit0_1\n")

      hits = client.memory.search_bytes(Bytes[0x90, 0x90])
      hits.should eq([0x401000_u64, 0x401050_u64])
    end
  end

  describe Cradare2::DSL::Debugger do
    it "controls execution and breakpoints" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.debug do |d|
        d.breakpoint("main")
        d.continue
        d.step
        d.step_over
        d.remove_breakpoint("main")
      end

      mock.history.should contain("db main")
      mock.history.should contain("dc")
      mock.history.should contain("ds")
      mock.history.should contain("dso")
      mock.history.should contain("db- main")
    end
  end
end
