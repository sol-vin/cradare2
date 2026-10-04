require "./spec_helper"
require "../src/cradare2/godot/lapis"

describe "Godot and Lapis Support" do
  describe Cradare2::Engine::Godot::GDExtensionInspector do
    it "verifies valid GDExtension library entrypoint" do
      mock = Cradare2::Transport::MockTransport.new do |cmd|
        case cmd
        when "iEj"
          <<-JSON
          [
            {"name": "lapis_gdextension_entry", "flagname": "sym.lapis_gdextension_entry", "offset": 4198400, "size": 64},
            {"name": "helper_func", "flagname": "sym.helper_func", "offset": 4198464, "size": 32}
          ]
          JSON
        when "ij"
          <<-JSON
          {"bin": {"arch": "x86", "bits": 64, "os": "windows"}}
          JSON
        else
          "[]"
        end
      end

      client = Cradare2::Client.new(mock)
      check = client.godot.verify_gdextension
      check.valid.should be_true
      check.entrypoint_found.should be_true
      check.entrypoint_name.should eq("lapis_gdextension_entry")
      check.exports_count.should eq(2)
      check.warnings.should be_empty
    end

    it "flags warnings on missing entrypoints" do
      mock = Cradare2::Transport::MockTransport.new do |cmd|
        case cmd
        when "iEj"
          <<-JSON
          [
            {"name": "random_export", "offset": 4198400, "size": 64}
          ]
          JSON
        when "ij"
          <<-JSON
          {"bin": {"arch": "x86", "bits": 64, "os": "windows"}}
          JSON
        else
          "[]"
        end
      end

      client = Cradare2::Client.new(mock)
      check = client.lapis.verify_gdextension
      check.valid.should be_false
      check.entrypoint_found.should be_false
      check.warnings.should_not be_empty
    end
  end

  describe Cradare2::Engine::Godot::Helper do
    it "registers Godot print formats" do
      executed = [] of String
      mock = Cradare2::Transport::MockTransport.new do |cmd|
        executed << cmd
        ""
      end

      client = Cradare2::Client.new(mock)
      client.godot.register_formats
      executed.should contain("pf.godot_object qqqq vtable instance_id user_data user_data_type")
      executed.should contain("pf.godot_variant b...q type _pad payload")
    end

    it "inspects vtable entries and resolves symbol names" do
      mock = Cradare2::Transport::MockTransport.new do |cmd|
        if cmd.starts_with?("pxj 16 @ 0x140001000")
          # 2 pointers: 0x140002000 and 0x140003000
          "[0, 32, 0, 64, 1, 0, 0, 0, 0, 48, 0, 64, 1, 0, 0, 0]"
        elsif cmd.starts_with?("fd @ 0x140002000")
          "sym.Godot.Node._ready"
        elsif cmd.starts_with?("fd @ 0x140003000")
          "sym.Godot.Node._process"
        else
          ""
        end
      end

      client = Cradare2::Client.new(mock)
      entries = client.godot.inspect_vtable(0x140001000, 2)
      entries.size.should eq(2)
      entries[0][1].should eq("sym.Godot.Node._ready")
      entries[1][1].should eq("sym.Godot.Node._process")
    end

    it "classifies crashes originating in Engine vs Bridge vs Unmapped" do
      mock = Cradare2::Transport::MockTransport.new do |cmd|
        case cmd
        when "drj"
          %({"pc": "0x14001000"})
        when "dmmj"
          <<-JSON
          [
            {"name": "godot.windows.opt.tools.64.exe", "addr": 5368709120, "addr_end": 5378709120},
            {"name": "lapis.dll", "addr": 335548416, "addr_end": 336548416}
          ]
          JSON
        else
          ""
        end
      end

      client = Cradare2::Client.new(mock)
      category, name = client.godot.classify_crash
      category.should eq("BRIDGE")
      name.should eq("lapis.dll")

      # Test unmapped
      mock.on("drj", %({"pc": "0xDEADBEEF"}))
      unmapped_cat, _ = client.godot.classify_crash
      unmapped_cat.should eq("UNMAPPED")
    end
  end
end
