require "./spec_helper"

describe "Types DSL Exhaustive Suite" do
  describe "#define_format" do
    it "defines a format with format specifiers and field names" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.types.define_format("my_struct", "bwdq", ["tag", "flags", "size", "offset"])
      executed.last.should eq("pf.my_struct bwdq tag flags size offset")
    end

    it "defines a format without field names" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.types.define_format("raw_bytes", "xxxx")
      executed.last.should eq("pf.raw_bytes xxxx")
    end

    it "handles all radare2 format specifiers (p, z, f, F, x, b, w, d, q)" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.types.define_format("complex_struct", "pzfFx", ["ptr", "name", "val_f", "val_d", "hex"])
      executed.last.should eq("pf.complex_struct pzfFx ptr name val_f val_d hex")
    end
  end

  describe "#define_struct" do
    it "defines a struct from a Hash(String, String) mapping field name to specifier" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.types.define_struct("player", {
        "id"     => "d",
        "health" => "w",
        "score"  => "q",
      })
      executed.last.should eq("pf.player dwq id health score")
    end

    it "defines a struct from Array of {format, field_name} tuples" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.types.define_struct("vector3", [
        {"f", "x"},
        {"f", "y"},
        {"f", "z"},
      ])
      executed.last.should eq("pf.vector3 fff x y z")
    end

    it "auto-detects and supports Array of {field_name, format} tuples" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.types.define_struct("quaternion", [
        {"x_coord", "f"},
        {"y_coord", "f"},
        {"z_coord", "f"},
        {"w_coord", "f"},
      ])
      executed.last.should eq("pf.quaternion ffff x_coord y_coord z_coord w_coord")
    end

    it "handles empty struct definition gracefully" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.types.define_struct("empty", [] of Tuple(String, String))
      executed.last.should eq("pf.empty ")
    end
  end

  describe "#format" do
    it "returns registered format string" do
      handler = ->(cmd : String) {
        cmd == "pf.godot_variant" ? "bbbbqq type_tag flags pad1 pad2 val0 val1" : ""
      }
      client = Cradare2.mock(handler)
      client.types.format("godot_variant").should eq("bbbbqq type_tag flags pad1 pad2 val0 val1")
    end

    it "returns nil when format is not defined" do
      handler = ->(cmd : String) { "Format 'missing_struct' not found." }
      client = Cradare2.mock(handler)
      client.types.format("missing_struct").should be_nil
    end

    it "returns nil when format query output is empty" do
      handler = ->(_cmd : String) { "" }
      client = Cradare2.mock(handler)
      client.types.format("empty_result").should be_nil
    end
  end

  describe "#delete_format" do
    it "deletes registered format using pf.-<name>" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.types.delete_format("old_struct")
      executed.last.should eq("pf.-old_struct")
    end
  end

  describe "#print_format" do
    it "decodes struct at address into Hash when pfj outputs an array of objects" do
      handler = ->(cmd : String) {
        cmd.should eq("pfj.player @ 0x140001000")
        <<-JSON
        [
          {"name": "id", "value": 101},
          {"name": "health", "value": 100},
          {"name": "name", "value": "Hero"}
        ]
        JSON
      }
      client = Cradare2.mock(handler)
      res = client.types.print_format("player", 0x140001000_u64)
      res.size.should eq(3)
      res["id"].as_i64.should eq(101)
      res["health"].as_i64.should eq(100)
      res["name"].as_s.should eq("Hero")
    end

    it "decodes struct at address when pfj outputs a direct JSON dictionary" do
      handler = ->(_cmd : String) {
        <<-JSON
        {"type_tag": 5, "val0": 123456789, "val1": 987654321}
        JSON
      }
      client = Cradare2.mock(handler)
      res = client.types.print_format("variant", 0x140002000_u64)
      res["type_tag"].as_i64.should eq(5)
      res["val0"].as_i64.should eq(123456789)
    end

    it "returns empty Hash when pfj output is empty" do
      handler = ->(_cmd : String) { "" }
      client = Cradare2.mock(handler)
      client.types.print_format("empty", 0x1000).should be_empty
    end

    it "raises TypeDefinitionError on corrupted JSON payload" do
      handler = ->(_cmd : String) { "error: invalid memory read { not json" }
      client = Cradare2.mock(handler)
      expect_raises(Cradare2::TypeDefinitionError, /Failed to parse pfj response/) do
        client.types.print_format("broken", 0x1000)
      end
    end

    it "supports string and register address arguments" do
      executed = [] of String
      handler = ->(cmd : String) {
        executed << cmd
        %([{"name":"reg","value":42}])
      }
      client = Cradare2.mock(handler)
      client.types.print_format("reg_struct", "0x5000")
      executed.last.should eq("pfj.reg_struct @ 0x5000")
    end
  end

  describe "C declarations" do
    it "raises TypeDefinitionError when C header file does not exist" do
      client = Cradare2.mock
      expect_raises(Cradare2::TypeDefinitionError, /Header file not found/) do
        client.types.parse_c_header("non_existent_header_123.h")
      end
    end

    it "parses C definition string and escapes quotes cleanly" do
      executed = [] of String
      handler = ->(cmd : String) { executed << cmd; "" }
      client = Cradare2.mock(handler)

      client.types.parse_c_definition("struct Point { int x; int y; };")
      executed.last.should eq("td \"struct Point { int x; int y; };\"")
    end
  end
end
