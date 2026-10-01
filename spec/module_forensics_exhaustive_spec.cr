require "./spec_helper"

describe "Module Forensics Exhaustive Suite" do
  describe Cradare2::Model::ModuleInfo do
    it "performs exact boundary containment checks" do
      mod = Cradare2::Model::ModuleInfo.new(
        name: "engine.dll",
        base_address: 0x140000000_u64,
        end_address: 0x140010000_u64,
        size: 0x10000_u64
      )

      # Below base
      mod.contains?(0x13fffffff_u64).should be_false
      # At base
      mod.contains?(0x140000000_u64).should be_true
      # Midpoint
      mod.contains?(0x140008000_u64).should be_true
      # 1 byte before end
      mod.contains?(0x14000ffff_u64).should be_true
      # At end (exclusive)
      mod.contains?(0x140010000_u64).should be_false
      # Beyond end
      mod.contains?(0x140010001_u64).should be_false
    end

    it "extracts basename cleanly across Windows and POSIX paths" do
      win_mod = Cradare2::Model::ModuleInfo.new("C:\\Program Files\\Godot\\godot.exe")
      win_mod.basename.should eq("godot.exe")

      posix_mod = Cradare2::Model::ModuleInfo.new("/usr/lib/x86_64-linux-gnu/libcrystal.so")
      posix_mod.basename.should eq("libcrystal.so")

      plain_mod = Cradare2::Model::ModuleInfo.new("lapis.dll")
      plain_mod.basename.should eq("lapis.dll")

      trailing_slash = Cradare2::Model::ModuleInfo.new("C:/games/my_plugin.dll/")
      trailing_slash.basename.should eq("my_plugin.dll")
    end

    it "computes size and addresses from constituent memory maps when raw fields are nil" do
      regions = [
        Cradare2::Model::MemoryMap.new(0x2000_u64, 0x3000_u64, "r-x", "submodule.so"),
        Cradare2::Model::MemoryMap.new(0x3000_u64, 0x4500_u64, "rw-", "submodule.so"),
        Cradare2::Model::MemoryMap.new(0x5000_u64, 0x6000_u64, "rw-", "submodule.so"),
      ]
      mod = Cradare2::Model::ModuleInfo.new("submodule.so", regions: regions)
      mod.base_address.should eq(0x2000_u64)
      mod.end_address.should eq(0x6000_u64)
      mod.size.should eq(0x4000_u64)
      mod.contains?(0x2500_u64).should be_true
      mod.contains?(0x5500_u64).should be_true
      mod.contains?(0x6500_u64).should be_false
    end

    it "formats display string in to_s" do
      mod = Cradare2::Model::ModuleInfo.new("test.dll", base_address: 0x1000_u64, end_address: 0x2000_u64)
      mod.to_s.should eq("test.dll [0x1000 - 0x2000]")
    end
  end

  describe "Debugger Module Forensics DSL" do
    multi_module_dmmj = <<-JSON
    [
      {"name": "godot.exe", "addr": 5368709120, "addr_end": 5373952000, "size": 5242880, "path": "C:\\\\games\\\\godot.exe"},
      {"name": "lapis.dll", "baddr": 5373952000, "addr_end": 5374083072, "size": 131072, "path": "C:\\\\games\\\\lapis.dll"},
      {"name": "steam_api64.dll", "addr": 5374083072, "addr_end": 5374345216, "size": 262144, "path": "C:\\\\games\\\\steam_api64.dll"}
    ]
    JSON

    it "discovers loaded modules from dmmj and preserves sort order by base address" do
      handler = ->(cmd : String) { cmd == "dmmj" ? multi_module_dmmj : "" }
      client = Cradare2.mock(handler)
      mods = client.debug.modules
      mods.size.should eq(3)
      mods[0].name.should eq("godot.exe")
      mods[1].name.should eq("lapis.dll")
      mods[2].name.should eq("steam_api64.dll")
    end

    it "resolves owning module for addresses across different loaded libraries" do
      handler = ->(cmd : String) { cmd == "dmmj" ? multi_module_dmmj : "" }
      client = Cradare2.mock(handler)

      # Inside godot.exe (base: 5368709120)
      m1 = client.debug.module_at(5368710000_u64)
      m1.should_not be_nil
      m1.not_nil!.name.should eq("godot.exe")

      # Inside lapis.dll (base: 5373952000)
      m2 = client.debug.module_at(5373960000_u64)
      m2.should_not be_nil
      m2.not_nil!.name.should eq("lapis.dll")

      # Inside steam_api64.dll (base: 5374083072)
      m3 = client.debug.module_at(5374100000_u64)
      m3.should_not be_nil
      m3.not_nil!.name.should eq("steam_api64.dll")
    end

    it "returns nil for addresses outside mapped module regions" do
      handler = ->(cmd : String) { cmd == "dmmj" ? multi_module_dmmj : "" }
      client = Cradare2.mock(handler)

      # Below lowest module base
      client.debug.module_at(1000_u64).should be_nil
      # Above highest module end
      client.debug.module_at(9999999999_u64).should be_nil
    end

    it "supports string and hex address arguments in module_at" do
      handler = ->(cmd : String) { cmd == "dmmj" ? multi_module_dmmj : "" }
      client = Cradare2.mock(handler)

      # 5368709120 = 0x140000000
      mod = client.debug.module_at("0x140001000")
      mod.should_not be_nil
      mod.not_nil!.name.should eq("godot.exe")
    end

    it "resolves base address with case-insensitive and partial matching" do
      handler = ->(cmd : String) { cmd == "dmmj" ? multi_module_dmmj : "" }
      client = Cradare2.mock(handler)

      # Exact match
      client.debug.base_address_of("godot.exe").should eq(5368709120_u64)
      # Mixed case
      client.debug.base_address_of("GoDoT.exe").should eq(5368709120_u64)
      # Full path
      client.debug.base_address_of("C:\\games\\lapis.dll").should eq(5373952000_u64)
      # Substring / basename without extension
      client.debug.base_address_of("steam_api64").should eq(5374083072_u64)
      # Non-existent
      client.debug.base_address_of("non_existent_module.dll").should be_nil
    end

    it "delegates module queries cleanly from top-level Client methods" do
      handler = ->(cmd : String) { cmd == "dmmj" ? multi_module_dmmj : "" }
      client = Cradare2.mock(handler)

      client.modules.size.should eq(3)
      client.module_at(5373960000_u64).try(&.name).should eq("lapis.dll")
      client.base_address_of("godot.exe").should eq(5368709120_u64)
    end
  end
end
