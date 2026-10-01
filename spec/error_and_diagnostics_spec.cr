require "./spec_helper"
require "../src/cradare2/version"

describe "Cradare2 Error Hierarchy & System Diagnostics" do
  describe "1. Exception Inheritance & Causes" do
    it "verifies all errors descend from Cradare2::Error" do
      errs = [
        Cradare2::TransportError.new("transport"),
        Cradare2::ProcessTerminatedError.new("terminated"),
        Cradare2::BinaryNotFoundError.new("not found"),
        Cradare2::SessionClosedError.new("closed"),
        Cradare2::ParseError.new("parse error"),
        Cradare2::CommandError.new("command failed"),
        Cradare2::TimeoutError.new("timeout"),
        Cradare2::SymbolResolutionError.new("symbol missing"),
        Cradare2::MemoryInspectionError.new("memory fault"),
        Cradare2::TypeDefinitionError.new("type error"),
      ]

      errs.each do |e|
        e.should be_a(Cradare2::Error)
      end

      # Hierarchy checks
      Cradare2::ProcessTerminatedError.new("").should be_a(Cradare2::TransportError)
      Cradare2::BinaryNotFoundError.new("").should be_a(Cradare2::TransportError)
    end

    it "preserves inner cause exceptions across wrapper errors" do
      root_cause = ArgumentError.new("Invalid base offset")
      wrapped = Cradare2::ParseError.new("Failed to parse", cause: root_cause)

      wrapped.cause.should eq(root_cause)
      wrapped.message.should eq("Failed to parse")
    end
  end

  describe "2. Client Parse & Session Error Raising" do
    it "raises ParseError with command and raw output when JSON is invalid" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("bad_json", "THIS IS NOT VALID JSON {[[}")

      expect_raises(Cradare2::ParseError, /Failed to parse JSON response for command 'bad_json'/) do
        client.cmdj("bad_json")
      end
    end

    it "raises ParseError when empty response is deserialized into a typed model" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("empty_resp", "   ")

      expect_raises(Cradare2::ParseError, /Empty response received/) do
        client.cmdj("empty_resp", as: Cradare2::Model::Breakpoint)
      end
    end

    it "raises SessionClosedError when executing commands on closed transport" do
      client = Cradare2.mock
      client.close
      client.closed?.should be_true

      expect_raises(Cradare2::SessionClosedError) do
        client.cmd("s 0x401000")
      end
    end
  end

  describe "3. Cradare2 Metadata & Version" do
    it "has a valid semantic version string" do
      Cradare2::VERSION.should match(/^\d+\.\d+\.\d+/)
    end

    it "matches shard.yml version" do
      shard_yml = File.read(File.join(__DIR__, "..", "shard.yml"))
      version_match = shard_yml.match(/^version:\s*([^\s\r\n#]+)/m)
      version_match.should_not be_nil
      Cradare2::VERSION.should eq(version_match.not_nil![1].strip("\"'"))
    end

    it "formats ProcessTerminatedError with diagnostics" do
      err = Cradare2::ProcessTerminatedError.new("Process died unexpected EOF\nRadare2 stderr: SIGSEGV")
      err.to_s.should contain("SIGSEGV")
    end

    it "formats BinaryNotFoundError with path" do
      err = Cradare2::BinaryNotFoundError.new("Executable 'r2' not found on system PATH")
      err.to_s.should contain("not found on system PATH")
    end

    it "handles CommandError with exit details" do
      err = Cradare2::CommandError.new("Command 'pdc' returned status 1: decompiler failed")
      err.to_s.should contain("status 1")
    end

    it "handles SymbolResolutionError and MemoryInspectionError" do
      sym_err = Cradare2::SymbolResolutionError.new("Could not resolve 'sym.missing'")
      sym_err.to_s.should contain("sym.missing")

      mem_err = Cradare2::MemoryInspectionError.new("Unmapped memory read at 0xdeadbeef")
      mem_err.to_s.should contain("0xdeadbeef")
    end

    it "handles TypeDefinitionError" do
      type_err = Cradare2::TypeDefinitionError.new("Invalid struct format 'pfd'")
      type_err.to_s.should contain("Invalid struct format")
    end
  end
end
