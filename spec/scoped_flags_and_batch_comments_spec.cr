require "./spec_helper"

describe "Scoped Flags and Batch Comments" do
  it "executes within a flag space and safely restores previous space" do
    executed = [] of String
    mock = Cradare2::Transport::MockTransport.new do |cmd|
      executed << cmd
      case cmd
      when "fs." then "original_space"
      else            ""
      end
    end

    client = Cradare2::Client.new(mock)

    client.flags.in_space("citrine") do |f|
      f.set("spram_start", 0x70000000)
    end

    executed.should contain("fs.")
    executed.should contain("fs citrine")
    executed.should contain("f spram_start @ 0x70000000")
    executed.should contain("fs original_space")
  end

  it "restores to clear_space when previous space was root or empty" do
    executed = [] of String
    mock = Cradare2::Transport::MockTransport.new do |cmd|
      executed << cmd
      case cmd
      when "fs." then ""
      else            ""
      end
    end

    client = Cradare2::Client.new(mock)

    client.flags.in_space("godot") do |f|
      f.set("entry", 0x1000)
    end

    executed.should contain("fs *")
  end

  it "batches multiple Base64 encoded comments" do
    executed = [] of String
    mock = Cradare2::Transport::MockTransport.new do |cmd|
      executed << cmd
      ""
    end

    client = Cradare2::Client.new(mock)

    comments = {
      0x1000_u64.as(Cradare2::Address) => "Line 10: Player._ready()",
      0x1020_u64.as(Cradare2::Address) => "Line 12: velocity = Vector2.ZERO",
    }

    client.comments.batch_set(comments)
    executed.size.should eq(1)
    batch_cmd = executed.first
    batch_cmd.should contain("CCu ")
    batch_cmd.should contain("@ 0x1000")
    batch_cmd.should contain("@ 0x1020")
  end
end
