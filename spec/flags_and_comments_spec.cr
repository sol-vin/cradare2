require "./spec_helper"
require "base64"

describe Cradare2::DSL::Flags do
  it "manages flags with set, get, delete, and rename" do
    executed_cmds = [] of String
    handler = ->(cmd : String) {
      executed_cmds << cmd
      case cmd
      when "?v sym.player_ready"
        "0x140001000"
      when "fj"
        <<-JSON
        [
          {"name": "sym.player_ready", "offset": 5368713216, "size": 64},
          {"name": "entrypoint", "offset": 5368709120, "size": 32}
        ]
        JSON
      else
        ""
      end
    }

    client = Cradare2.mock(handler)

    # Set flag
    client.flags.set("sym.player_ready", 0x140001000_u64, 64)
    executed_cmds.last.should eq("f sym.player_ready 64 0x140001000")

    # Get flag
    addr = client.flags.get("sym.player_ready")
    addr.should eq(0x140001000_u64)

    # Delete flag
    client.flags.delete("sym.player_ready")
    executed_cmds.last.should eq("f- sym.player_ready")

    # Rename flag
    client.flags.rename("old_sym", "new_sym")
    executed_cmds.last.should eq("fr old_sym new_sym")

    # All flags & matching
    all_flags = client.flags.all
    all_flags.size.should eq(2)
    matching = client.flags.matching(/player/)
    matching.size.should eq(1)
    matching.first.name.should eq("sym.player_ready")
  end

  it "batch sets flags in command streams" do
    executed_cmds = [] of String
    handler = ->(cmd : String) {
      executed_cmds << cmd
      ""
    }
    client = Cradare2.mock(handler)
    flags_map = {
      "sym.godot_node"   => 0x140001000_u64.as(Cradare2::Address),
      "sym.godot_sprite" => 0x140002000_u64.as(Cradare2::Address),
    }
    client.flags.batch_set(flags_map)
    executed_cmds.any? { |c| c.includes?("f sym.godot_node @ 0x140001000") && c.includes?("f sym.godot_sprite @ 0x140002000") }.should be_true
  end

  it "manages flag spaces with space, current_space, and clear_space" do
    executed_cmds = [] of String
    handler = ->(cmd : String) {
      executed_cmds << cmd
      case cmd
      when "fs."
        "godot"
      when "fs"
        "0 * default\n1 . godot\n"
      else
        ""
      end
    }
    client = Cradare2.mock(handler)

    client.flags.space("godot")
    executed_cmds.last.should eq("fs godot")

    client.flags.current_space.should eq("godot")
    client.flags.spaces.should contain("godot")

    client.flags.clear_space
    executed_cmds.last.should eq("fs *")
  end
end

describe Cradare2::DSL::Comments do
  it "sets comments using safe Base64 encoding" do
    executed_cmds = [] of String
    handler = ->(cmd : String) {
      executed_cmds << cmd
      case cmd
      when "CC. @ 0x140001000"
        "Player#ready initialization; key=\"val\""
      when "Cj"
        <<-JSON
        [
          {"offset": 5368713216, "name": "Player#ready initialization"}
        ]
        JSON
      else
        ""
      end
    }

    client = Cradare2.mock(handler)

    # Set comment with quotes and semicolons
    raw_comment = "Player#ready: function() { return 42; };"
    client.comments.set(0x140001000_u64, raw_comment)

    encoded = Base64.strict_encode(raw_comment)
    executed_cmds.last.should eq("CCu #{encoded} @ 0x140001000")

    # Get comment
    text = client.comments.get(0x140001000_u64)
    text.should eq("Player#ready initialization; key=\"val\"")

    # Clear comment
    client.comments.clear(0x140001000_u64)
    executed_cmds.last.should eq("CC- @ 0x140001000")

    # All comments
    all_comments = client.comments.all
    all_comments.size.should eq(1)
    all_comments[5368713216_u64]?.should eq("Player#ready initialization")
  end
end
