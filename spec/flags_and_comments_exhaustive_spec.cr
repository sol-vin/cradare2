require "./spec_helper"
require "base64"

describe "Flags & Comments DSL Exhaustive Suite" do
  describe "Flags DSL" do
    it "sets flags with name, size, and address" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.flags.set("sym.godot_node", 0x140001000_u64, size: 128)
      executed.last.should eq("f sym.godot_node 128 0x140001000")
    end

    it "sets flags without explicit size using '@ address'" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.flags.set("sym.entry", 0x140000000_u64)
      executed.last.should eq("f sym.entry @ 0x140000000")
    end

    it "handles flag names with dots, colons, underscores, and dashes" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.flags.set("godot:Node2D.get_transform-v1", 0x140005000_u64)
      executed.last.should eq("f godot:Node2D.get_transform-v1 @ 0x140005000")
    end

    it "resolves flag address via ?v <name>" do
      handler = ->(cmd : String) {
        cmd == "?v sym.player_jump" ? "0x140009999" : ""
      }
      client = Cradare2.mock(handler)
      client.flags.get("sym.player_jump").should eq(0x140009999_u64)
    end

    it "returns nil when getting address of non-existent flag" do
      handler = ->(cmd : String) {
        cmd.starts_with?("?v") ? "0x0" : ""
      }
      client = Cradare2.mock(handler)
      client.flags.get("missing_symbol").should be_nil
    end

    it "renames flags using fr <old> <new>" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.flags.rename("old_label", "new_label")
      executed.last.should eq("fr old_label new_label")
    end

    it "deletes flags by name using f- <name>" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.flags.delete("temp_flag")
      executed.last.should eq("f- temp_flag")
    end

    it "batch sets up to 500 flags in a single command stream" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      flags_map = Hash(String, Cradare2::Address).new
      500.times do |i|
        flags_map["sym.classdb_symbol_#{i}"] = (0x140000000_u64 + (i * 0x10)).as(Cradare2::Address)
      end

      client.flags.batch_set(flags_map)
      executed.size.should eq(10) # 500 flags chunked into groups of 50
      executed.first.should contain("f sym.classdb_symbol_0 @ 0x140000000")
      executed.last.should contain("f sym.classdb_symbol_499 @ 0x140001f30")
    end

    it "handles empty batch set gracefully" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.flags.batch_set(Hash(String, Cradare2::Address).new)
      executed.should be_empty
    end

    it "filters flags with regex patterns and substrings" do
      handler = ->(cmd : String) {
        if cmd == "fj"
          <<-JSON
          [
            {"name": "sym.godot.Node.process", "offset": 1000, "size": 64},
            {"name": "sym.godot.Node.ready", "offset": 2000, "size": 32},
            {"name": "sym.lapis.Player.fire", "offset": 3000, "size": 48}
          ]
          JSON
        else
          ""
        end
      }
      client = Cradare2.mock(handler)

      godot_flags = client.flags.matching(/godot/)
      godot_flags.size.should eq(2)
      godot_flags.map(&.name).should contain("sym.godot.Node.process")

      player_flags = client.flags.matching("Player")
      player_flags.size.should eq(1)
      player_flags.first.name.should eq("sym.lapis.Player.fire")
    end

    it "manages multiple flag spaces (switching, querying, clearing)" do
      executed = [] of String
      handler = ->(cmd : String) {
        executed << cmd
        case cmd
        when "fs." then "godot"
        when "fs"  then "0 * default\n1 . godot\n2 . lapis\n3 . engine\n"
        else            ""
        end
      }
      client = Cradare2.mock(handler)

      client.flags.space("godot")
      executed.last.should eq("fs godot")

      client.flags.current_space.should eq("godot")
      client.flags.spaces.should eq(["default", "godot", "lapis", "engine"])

      client.flags.clear_space
      executed.last.should eq("fs *")
    end
  end

  describe "Comments DSL" do
    it "sets comments using Base64 encoding" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      comment = "MyClass#method(arg: Int32)"
      client.comments.set(0x140001000_u64, comment)
      expected_b64 = Base64.strict_encode(comment)
      executed.last.should eq("CCu #{expected_b64} @ 0x140001000")
    end

    it "safely handles multi-line comments" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      multi = "Line 1: Prologue\nLine 2: Body\nLine 3: Epilogue"
      client.comments.set(0x140002000_u64, multi)
      expected_b64 = Base64.strict_encode(multi)
      executed.last.should eq("CCu #{expected_b64} @ 0x140002000")
    end

    it "safely handles quotes, semicolons, and brackets without breaking shell syntax" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      tricky = "puts \\\"Result: \#{x}\\\"; arr[0] = 'a';"
      client.comments.set(0x140003000_u64, tricky)
      expected_b64 = Base64.strict_encode(tricky)
      executed.last.should eq("CCu #{expected_b64} @ 0x140003000")
    end

    it "handles Unicode and Emoji comments" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      emoji_comment = "Crash site 💀 - Target: 🚀 Godot 4.3"
      client.comments.set(0x140004000_u64, emoji_comment)
      expected_b64 = Base64.strict_encode(emoji_comment)
      executed.last.should eq("CCu #{expected_b64} @ 0x140004000")
    end

    it "auto-decodes Base64 comments returned by radare2 in get" do
      raw_text = "Function entrypoint"
      encoded = Base64.strict_encode(raw_text)
      handler = ->(cmd : String) {
        cmd == "CC. @ 0x140005000" ? encoded : ""
      }
      client = Cradare2.mock(handler)
      client.comments.get(0x140005000_u64).should eq("Function entrypoint")
    end

    it "returns plain text directly if comment is not base64 encoded" do
      handler = ->(cmd : String) {
        cmd == "CC. @ 0x140006000" ? "Plain Text Comment" : ""
      }
      client = Cradare2.mock(handler)
      client.comments.get(0x140006000_u64).should eq("Plain Text Comment")
    end

    it "returns nil when address has no comment" do
      handler = ->(cmd : String) {
        cmd.starts_with?("CC.") ? "No comment" : ""
      }
      client = Cradare2.mock(handler)
      client.comments.get(0x140007000_u64).should be_nil
    end

    it "clears a single comment with CC- @ addr" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.comments.clear(0x140008000_u64)
      executed.last.should eq("CC- @ 0x140008000")
    end

    it "clears all comments with CC-*" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.comments.clear_all
      executed.last.should eq("CC-*")
    end

    it "returns all session comments with auto-decoding in all" do
      c1_enc = Base64.strict_encode("Comment One")
      c2_enc = Base64.strict_encode("Comment Two")
      handler = ->(cmd : String) {
        if cmd == "Cj"
          <<-JSON
          [
            {"offset": 4096, "name": "#{c1_enc}"},
            {"addr": 8192, "comment": "#{c2_enc}"},
            {"offset": 12288, "name": "Already Plain"}
          ]
          JSON
        else
          ""
        end
      }
      client = Cradare2.mock(handler)
      all_comments = client.comments.all
      all_comments.size.should eq(3)
      all_comments[4096_u64]?.should eq("Comment One")
      all_comments[8192_u64]?.should eq("Comment Two")
      all_comments[12288_u64]?.should eq("Already Plain")
    end
  end
end
