require "./spec_helper"

describe Cradare2::DSL::Types do
  it "defines print formats and decodes structs with pfj" do
    executed_cmds = [] of String
    handler = ->(cmd : String) {
      executed_cmds << cmd
      case cmd
      when "pf.godot_variant"
        "bbbbqq type_tag flags pad1 pad2 val0 val1"
      when "pfj.godot_variant @ 0x140001000"
        <<-JSON
        [
          {"name": "type_tag", "type": "b", "value": 4},
          {"name": "flags", "type": "b", "value": 0},
          {"name": "val0", "type": "q", "value": 140723423000}
        ]
        JSON
      else
        ""
      end
    }

    client = Cradare2.mock(handler)

    # Define format
    client.types.define_format("godot_variant", "bbbbqq", ["type_tag", "flags", "pad1", "pad2", "val0", "val1"])
    executed_cmds.last.should eq("pf.godot_variant bbbbqq type_tag flags pad1 pad2 val0 val1")

    # Define struct helper
    client.types.define_struct("player_stats", {"hp" => "d", "mana" => "d", "score" => "q"})
    executed_cmds.last.should eq("pf.player_stats ddq hp mana score")

    # Format inspection
    fmt = client.types.format("godot_variant")
    fmt.should eq("bbbbqq type_tag flags pad1 pad2 val0 val1")

    # Print format JSON decoding
    decoded = client.types.print_format("godot_variant", 0x140001000_u64)
    decoded["type_tag"].as_i.should eq(4)
    decoded["flags"].as_i.should eq(0)
    decoded["val0"].as_i64.should eq(140723423000_i64)

    # Delete format
    client.types.delete_format("godot_variant")
    executed_cmds.last.should eq("pf.-godot_variant")
  end
end
