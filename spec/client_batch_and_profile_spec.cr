require "./spec_helper"

describe "Client batch execution, profiling hooks, and safe_cmdj" do
  describe "#batch" do
    it "handles empty command arrays" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)
      client.batch([] of String).should be_empty
      executed.should be_empty
    end

    it "batches multiple commands sequentially, returning command-to-output map" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "ok:#{cmd}" }
      client = Cradare2.mock(handler)
      res = client.batch(["s 0x1000", "wx 9090", "s 0x2000"])
      res.size.should eq(3)
      res["s 0x1000"].should eq("ok:s 0x1000")
      res["wx 9090"].should eq("ok:wx 9090")
      res["s 0x2000"].should eq("ok:s 0x2000")
      executed.should eq(["s 0x1000", "wx 9090", "s 0x2000"])
    end

    it "strips empty strings and trailing whitespace" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "done" }
      client = Cradare2.mock(handler)
      res = client.batch(["  s 0x100  ", "", "   ", "px 16"])
      res.size.should eq(2)
      res.has_key?("s 0x100").should be_true
      res.has_key?("px 16").should be_true
      executed.should eq(["s 0x100", "px 16"])
    end

    it "handles batch containing comments and special characters" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "success" }
      client = Cradare2.mock(handler)
      res = client.batch(["# analysis batch", "af-", "af @ 0x4000; CC \"entry\" @ 0x4000"])
      res.size.should eq(3)
      executed.should eq(["# analysis batch", "af-", "af @ 0x4000; CC \"entry\" @ 0x4000"])
    end
  end

  describe "#on_command profiling hooks" do
    it "invokes callback with command string and elapsed time" do
      captured_cmd = ""
      captured_elapsed = Time::Span.zero

      client = Cradare2.mock(->(cmd : String) { sleep 1.millisecond; "output" })
      client.on_command do |cmd, elapsed|
        captured_cmd = cmd
        captured_elapsed = elapsed
      end

      client.cmd("?v 42")
      captured_cmd.should eq("?v 42")
      captured_elapsed.should be > Time::Span.zero
    end

    it "supports multiple chained callbacks" do
      hook1_calls = 0
      hook2_calls = 0

      client = Cradare2.mock(->(cmd : String) { "response" })
      client.on_command { |_cmd, _el| hook1_calls += 1 }
      client.on_command { |_cmd, _el| hook2_calls += 1 }

      client.cmd("iI")
      client.cmd("afl")

      hook1_calls.should eq(2)
      hook2_calls.should eq(2)
    end

    it "triggers profiling hook during cmdj queries" do
      invoked = false
      client = Cradare2.mock(->(cmd : String) { %({"key":"value"}) })
      client.on_command do |cmd, _elapsed|
        invoked = true
        cmd.should eq("ij")
      end

      res = client.cmdj("ij")
      invoked.should be_true
      res["key"].as_s.should eq("value")
    end

    it "clears callbacks with clear_command_hooks" do
      calls = 0
      client = Cradare2.mock(->(cmd : String) { "ok" })
      client.on_command { |_cmd, _el| calls += 1 }
      client.cmd("s 0x10")
      calls.should eq(1)

      client.clear_command_hooks
      client.cmd("s 0x20")
      calls.should eq(1)
    end
  end

  describe "#safe_cmdj" do
    it "parses valid JSON response into specified model" do
      client = Cradare2.mock(->(cmd : String) { %([{"name":"sym.main","offset":4198400,"size":32}]) })
      symbols = client.safe_cmdj("isj", as: Array(Cradare2::Model::Symbol))
      symbols.should_not be_nil
      symbols.not_nil!.size.should eq(1)
      symbols.not_nil!.first.name.should eq("sym.main")
    end

    it "returns nil for completely empty response" do
      client = Cradare2.mock(->(cmd : String) { "" })
      client.safe_cmdj("isj", as: Array(Cradare2::Model::Symbol)).should be_nil
    end

    it "returns nil for whitespace-only response" do
      client = Cradare2.mock(->(cmd : String) { "   \n\t  " })
      client.safe_cmdj("isj", as: Array(Cradare2::Model::Symbol)).should be_nil
    end

    it "returns nil gracefully when radare2 emits malformed JSON" do
      client = Cradare2.mock(->(cmd : String) { "{ invalid json syntax ... [" })
      client.safe_cmdj("ij", as: Cradare2::Model::BinaryInfo).should be_nil
    end

    it "returns nil gracefully on JSON structure mismatch (array vs object)" do
      client = Cradare2.mock(->(cmd : String) { %([1, 2, 3]) })
      # Expecting BinaryInfo object, received array of ints
      client.safe_cmdj("ij", as: Cradare2::Model::BinaryInfo).should be_nil
    end

    it "returns JSON::Any dynamically without type argument" do
      client = Cradare2.mock(->(cmd : String) { %({"version":"5.9.0","arch":"x86"}) })
      dyn = client.safe_cmdj("ij")
      dyn.should_not be_nil
      dyn.not_nil!["version"].as_s.should eq("5.9.0")
    end

    it "returns nil dynamically on invalid JSON without type argument" do
      client = Cradare2.mock(->(cmd : String) { "Cannot parse this" })
      client.safe_cmdj("ij").should be_nil
    end
  end
end
