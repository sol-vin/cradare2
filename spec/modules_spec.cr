require "./spec_helper"

describe Cradare2::Model::ModuleInfo do
  it "calculates base address, end address, size, and containment" do
    mod = Cradare2::Model::ModuleInfo.new(
      name: "game.dll",
      base_address: 0x140000000_u64,
      end_address: 0x140050000_u64,
      path: "C:\\dev\\game.dll"
    )

    mod.name.should eq("game.dll")
    mod.base_address.should eq(0x140000000_u64)
    mod.end_address.should eq(0x140050000_u64)
    mod.size.should eq(0x50000_u64)
    mod.path.should eq("C:\\dev\\game.dll")

    mod.contains?(0x140000000_u64).should be_true
    mod.contains?(0x140025000_u64).should be_true
    mod.contains?(0x140050000_u64).should be_false
    mod.contains?(0x13fffffff_u64).should be_false
  end

  it "derives boundaries from constituent memory regions" do
    regions = [
      Cradare2::Model::MemoryMap.new(0x140000000_u64, 0x140010000_u64, "r-x", "bridge.dll"),
      Cradare2::Model::MemoryMap.new(0x140010000_u64, 0x140025000_u64, "rw-", "bridge.dll"),
    ]
    mod = Cradare2::Model::ModuleInfo.new("bridge.dll", regions: regions)

    mod.base_address.should eq(0x140000000_u64)
    mod.end_address.should eq(0x140025000_u64)
    mod.size.should eq(0x25000_u64)
    mod.contains?(0x140015000_u64).should be_true
  end
end

describe "Debugger module forensics" do
  it "parses loaded modules from dmmj" do
    handler = ->(cmd : String) {
      case cmd
      when "dmmj"
        <<-JSON
        [
          {"name": "godot.exe", "addr": 5368709120, "addr_end": 5373952000, "size": 5242880},
          {"name": "plugin.dll", "addr": 5373952000, "addr_end": 5374083072, "size": 131072}
        ]
        JSON
      else
        ""
      end
    }

    client = Cradare2.mock(handler)
    mods = client.debug.modules
    mods.size.should eq(2)
    mods[0].name.should eq("godot.exe")
    mods[0].base_address.should eq(5368709120_u64)
    mods[1].name.should eq("plugin.dll")

    # module_at
    mod_found = client.debug.module_at(5373955000_u64)
    mod_found.should_not be_nil
    mod_found.not_nil!.name.should eq("plugin.dll")

    # base_address_of
    client.debug.base_address_of("godot.exe").should eq(5368709120_u64)
    client.base_address_of("plugin.dll").should eq(5373952000_u64)
  end

  it "falls back to grouping dmj memory maps when dmmj is unavailable" do
    handler = ->(cmd : String) {
      case cmd
      when "dmmj"
        "[]"
      when "dmj"
        <<-JSON
        [
          {"name": "C:\\\\games\\\\game.dll", "addr": 4194304, "addr_end": 4227072, "perm": "-r-x"},
          {"name": "C:\\\\games\\\\game.dll", "addr": 4227072, "addr_end": 4259840, "perm": "-rw-"},
          {"name": "[stack]", "addr": 140723400000, "addr_end": 140723500000, "perm": "-rw-"}
        ]
        JSON
      else
        ""
      end
    }

    client = Cradare2.mock(handler)
    mods = client.modules
    mods.size.should eq(1)
    mods.first.name.should eq("game.dll")
    mods.first.base_address.should eq(4194304_u64)
    mods.first.end_address.should eq(4259840_u64)

    client.module_at(4200000_u64).try(&.name).should eq("game.dll")
    client.module_at(140723405000_u64).should be_nil # [stack] is filtered out
  end
end
