require "./spec_helper"

describe Cradare2::Transport do
  describe Cradare2::Transport::MockTransport do
    it "records command history" do
      mock = Cradare2::Transport::MockTransport.new
      mock.cmd("aaa")
      mock.cmd("aflj")
      mock.history.should eq(["aaa", "aflj"])
    end

    it "matches exact command handlers" do
      mock = Cradare2::Transport::MockTransport.new
      mock.on("version", "radare2 6.2.2")
      mock.cmd("version").should eq("radare2 6.2.2")
    end

    it "matches regex command handlers" do
      mock = Cradare2::Transport::MockTransport.new
      mock.on(/^px \d+/) { |cmd| "hexdump for #{cmd}" }
      mock.cmd("px 16").should eq("hexdump for px 16")
    end

    it "falls back to default handler" do
      mock = Cradare2::Transport::MockTransport.new
      mock.default { |cmd| "default: #{cmd}" }
      mock.cmd("unknown").should eq("default: unknown")
    end

    it "raises SessionClosedError when executed after close" do
      mock = Cradare2::Transport::MockTransport.new
      mock.close
      expect_raises(Cradare2::SessionClosedError) do
        mock.cmd("test")
      end
    end

    it "resets state" do
      mock = Cradare2::Transport::MockTransport.new
      mock.cmd("hello")
      mock.close
      mock.reset
      mock.closed?.should be_false
      mock.history.should be_empty
    end
  end

  describe Cradare2::Transport::ProcessTransport do
    it "spawns radare2 with null-byte delimiter communication" do
      r2_bin = Process.find_executable("r2") || Process.find_executable("radare2")
      if r2_bin
        transport = Cradare2::Transport::ProcessTransport.new("malloc://64")
        begin
          res = transport.cmd("?e cradare2_live_test")
          res.strip.should eq("cradare2_live_test")

          # Test JSON command
          json_res = transport.cmd("ij")
          json_res.should contain("core")
        ensure
          transport.close
        end
        transport.closed?.should be_true
      end
    end

    it "raises BinaryNotFoundError for non-existent executable" do
      expect_raises(Cradare2::BinaryNotFoundError) do
        Cradare2::Transport::ProcessTransport.new("malloc://64", r2_path: "non_existent_binary_xyz_123")
      end
    end
  end

  describe Cradare2::Transport::HttpTransport do
    it "validates HTTP URL scheme" do
      expect_raises(Cradare2::TransportError, /Invalid HTTP URI scheme/) do
        Cradare2::Transport::HttpTransport.new("ftp://localhost:9090")
      end
    end
  end

  describe Cradare2::Transport::TcpTransport do
    it "validates TCP URL scheme" do
      expect_raises(Cradare2::TransportError, /Invalid TCP URI scheme/) do
        Cradare2::Transport::TcpTransport.new("http://localhost:9090")
      end
    end
  end

  describe Cradare2::Transport::InSessionTransport do
    it "raises TransportError when in-session environment variables are missing" do
      # Temporarily ensure env vars are clear
      old_in = ENV["R2PIPE_IN"]?
      old_out = ENV["R2PIPE_OUT"]?
      old_path = ENV["R2PIPE_PATH"]?
      ENV.delete("R2PIPE_IN")
      ENV.delete("R2PIPE_OUT")
      ENV.delete("R2PIPE_PATH")

      begin
        expect_raises(Cradare2::TransportError, /In-session r2pipe environment variables/) do
          Cradare2::Transport::InSessionTransport.new
        end
      ensure
        ENV["R2PIPE_IN"] = old_in if old_in
        ENV["R2PIPE_OUT"] = old_out if old_out
        ENV["R2PIPE_PATH"] = old_path if old_path
      end
    end
  end

  describe Cradare2::Util::Locator do
    it "finds existing r2 binary in system" do
      path = Cradare2::Util::Locator.find_r2
      File.exists?(path).should be_true
    end

    it "accepts custom r2 binary path" do
      existing = Cradare2::Util::Locator.find_r2
      custom = Cradare2::Util::Locator.find_r2(existing)
      custom.should eq(existing)
    end
  end
end
