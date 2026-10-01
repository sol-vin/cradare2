require "./spec_helper"

class MockEchoCommand < Cradare2::Plugin::Command
  def initialize(prefix_name : String = "mock")
    super(
      name: "echo",
      summary: "Echo command for #{prefix_name}",
      usage: "#{prefix_name} echo <text>",
      aliases: ["ec"]
    )
  end

  def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
    if json
      {"suite" => @usage.split.first, "args" => args}.to_json
    else
      "#{@usage.split.first.upcase}: #{args.join(" ")}"
    end
  end
end

class MockCustomCommand < Cradare2::Plugin::Command
  def initialize(name : String)
    super(name: name, summary: "Custom #{name} command", usage: "#{name} [opts]")
  end

  def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
    "EXECUTED_#{name.upcase}"
  end
end

describe "Upstream Additions for Lapis and Godot Integration" do
  describe Cradare2::Options do
    it "configures attach_pid with fluent builder" do
      opts = Cradare2::Options.build do |o|
        o.attach_pid(9999)
      end

      opts.attach_pid.should eq(9999_i64)
      opts.debug.should be_true
      opts.write.should be_true
    end

    it "copies attach_pid on clone" do
      opts = Cradare2::Options.new(attach_pid: 12345_i64, debug: true, write: true)
      cloned = opts.clone
      cloned.attach_pid.should eq(12345_i64)
      cloned.debug.should be_true
      cloned.write.should be_true
    end
  end

  describe "Disassembly Extensions" do
    it "executes side_by_side decompilation (pdca)" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("af @ 0x401000", "")
      mock.on("pdca @ 0x401000", "0x401000  sub rsp, 28  |  void main() {")

      res = client.disasm.side_by_side(0x401000_u64, auto_analyze: true)
      res.should contain("void main()")
    end

    it "falls back to decompile when pdca returns 'Cannot'" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("pdca @ 0x401000", "Cannot find function at 0x401000")
      mock.on("pdg @ 0x401000", "Cannot run pdg")
      mock.on("pdc @ 0x401000", "int fallback_decomp() { return 1; }")

      res = client.disasm.side_by_side(0x401000_u64, auto_analyze: false)
      res.should eq("int fallback_decomp() { return 1; }")
    end

    it "executes source_interleaved disassembly (pdls)" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("pdls 15 @ 0x401000", "line 10: x = 1\n0x401000  mov [rax], 1")

      res = client.disasm.source_interleaved(0x401000_u64, count: 15)
      res.should contain("line 10: x = 1")
    end

    it "executes annotated_source decompilation (CLd)" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("CLd @ 0x401000", "/* file.c:20 */\nint x = 42;")

      res = client.disasm.annotated_source(0x401000_u64)
      res.should contain("/* file.c:20 */")
    end

    it "falls back to assembly when decompilation fails and fallback_asm is true" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("pdg @ 0x401000", "Cannot run pdg")
      mock.on("pdc @ 0x401000", "Cannot find function")
      mock.on("pdf @ 0x401000", "push rbp\nmov rbp, rsp")

      res = client.disasm.decompile(0x401000_u64, auto_analyze: false, fallback_asm: true)
      res.should contain("push rbp")
    end
  end

  describe "Crystal#decompile_method" do
    it "decompiles method by class and method name" do
      client = SpecFixtures.build_mock_client
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("af @ 0x401258", "")
      mock.on("pdg @ 0x401258", "Cannot run pdg")
      mock.on("pdc @ 0x401258", "void Player_ready() { godot_string_new(); }")

      decomp = client.crystal.decompile_method("MyGame::Player", "_ready")
      decomp.should contain("Player_ready()")
    end

    it "supports side-by-side mode in decompile_method" do
      client = SpecFixtures.build_mock_client
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("af @ 0x401258", "")
      mock.on("pdca @ 0x401258", "sub rsp, 28 | void Player_ready()")

      decomp = client.crystal.decompile_method("MyGame::Player", "_ready", side_by_side: true)
      decomp.should contain("sub rsp, 28 | void Player_ready()")
    end

    it "returns informative message when method is not found" do
      client = SpecFixtures.build_mock_client
      res = client.crystal.decompile_method("NonExistent", "missing_method")
      res.should contain("not found in analyzed binary symbols")
    end
  end

  describe Cradare2::Plugin::Router do
    it "mounts multiple dispatchers and routes by prefix" do
      client = Cradare2.mock
      router = Cradare2::Plugin::Router.new(client)

      godot_disp = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "godot")
      godot_disp.register(MockEchoCommand.new("godot"))

      lapis_disp = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "lapis")
      lapis_disp.register(MockEchoCommand.new("lapis"))

      router.mount("godot", godot_disp)
      router.mount("lapis", lapis_disp)

      router.dispatch("godot echo hello from godot").should eq("GODOT: hello from godot")
      router.dispatch("lapis echo hello from lapis").should eq("LAPIS: hello from lapis")
    end

    it "supports block mounting syntax" do
      client = Cradare2.mock
      router = Cradare2::Plugin::Router.new(client)

      router.mount("custom") do |disp|
        disp.register(MockCustomCommand.new("ping"))
      end

      router.dispatch("custom ping").should eq("EXECUTED_PING")
    end

    it "supports colon prefix syntax (e.g. 'godot:echo')" do
      client = Cradare2.mock
      router = Cradare2::Plugin::Router.new(client)

      godot_disp = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "godot")
      godot_disp.register(MockEchoCommand.new("godot"))
      router.mount("godot", godot_disp)

      router.dispatch("godot:echo test argument").should eq("GODOT: test argument")
    end

    it "handles universal -j / --json flag across routes" do
      client = Cradare2.mock
      router = Cradare2::Plugin::Router.new(client)

      lapis_disp = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "lapis")
      lapis_disp.register(MockEchoCommand.new("lapis"))
      router.mount("lapis", lapis_disp)

      json = router.dispatch("lapis echo item1 item2 -j")
      parsed = JSON.parse(json)
      parsed["suite"].as_s.should eq("lapis")
      parsed["args"].as_a.map(&.as_s).should eq(["item1", "item2"])
    end

    it "routes directly to subcommand when prefix is omitted" do
      client = Cradare2.mock
      router = Cradare2::Plugin::Router.new(client)

      engine_disp = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "engine")
      engine_disp.register(MockCustomCommand.new("inspect_node"))
      router.mount("engine", engine_disp)

      router.dispatch("inspect_node").should eq("EXECUTED_INSPECT_NODE")
    end

    it "generates aggregated help menu for all mounted suites" do
      client = Cradare2.mock
      router = Cradare2::Plugin::Router.new(client)

      disp1 = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "godot")
      disp1.register(MockEchoCommand.new("godot"))

      disp2 = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "lapis")
      disp2.register(MockCustomCommand.new("reload"))

      router.mount("godot", disp1)
      router.mount("lapis", disp2)

      help = router.help
      help.should contain("=== GODOT COMMANDS")
      help.should contain("=== LAPIS COMMANDS")
      help.should contain("echo")
      help.should contain("reload")

      # Empty input returns help
      router.dispatch("").should eq(help)
    end

    it "runs with Server.run loop" do
      client = Cradare2.mock
      router = Cradare2::Plugin::Router.new(client)

      disp = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "test")
      disp.register(MockCustomCommand.new("hello"))
      router.mount("test", disp)

      in_io = IO::Memory.new("test hello\nquit\n")
      out_io = IO::Memory.new

      Cradare2::Plugin::Server.run(router, in_io, out_io)
      out_io.to_s.should contain("EXECUTED_HELLO")
    end
  end

  describe "Debugger Hot-Reload Stale VTable Detection" do
    it "detects stale vtable pointer pointing outside mapped modules" do
      client = SpecFixtures.build_mock_client
      # game.dll is mapped 4194304 (0x400000) to 4259840 (0x410000)
      # [stack] is mapped 140723400000 to 140723500000

      # An address in game.dll is NOT stale
      client.debug.stale_vtable?(0x401000_u64).should be_false

      # An unmapped high address IS stale
      client.debug.stale_vtable?(0x7FFF99990000_u64).should be_true

      # Low null/guard addresses (< 0x10000) are not treated as stale vtables
      client.debug.stale_vtable?(0x0_u64).should be_false
      client.debug.stale_vtable?(0x100_u64).should be_false
    end

    it "scans registers to find objects holding stale vtables" do
      client = SpecFixtures.build_mock_client
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      # Register rcx holds pointer to a Godot object at 0x500000
      mock.on("?v rcx", "0x500000")
      mock.on("?v rdi", "0x0")
      mock.on("?v rsi", "0x0")
      mock.on("?v rbx", "0x0")

      # Object at 0x500000 has vtable pointing to an unloaded previous DLL at 0x7FFF88880000
      # 0x7FFF88880000 in little endian 8 bytes: 00 00 88 88 FF 7F 00 00 -> [0, 0, 136, 136, 255, 127, 0, 0]
      mock.on("pxj 8 @ 0x500000", "[0, 0, 136, 136, 255, 127, 0, 0]")

      stale_list = client.debug.find_stale_vtables(registers_to_scan: ["rcx", "rdi", "rsi", "rbx"])
      stale_list.size.should eq(1)
      stale_list.first[:register].should eq("rcx")
      stale_list.first[:object_address].should eq(0x500000_u64)
      stale_list.first[:vtable].should eq(0x7FFF88880000_u64)
      stale_list.first[:reason].should contain("stale hot-reload pointer")
    end
  end

  describe Cradare2::Engine::Godot do
    it "decodes GodotObjectHeader binary structure" do
      io = IO::Memory.new
      IO::ByteFormat::LittleEndian.encode(0x401000_u64, io) # vtable
      IO::ByteFormat::LittleEndian.encode(42_u64, io)       # instance_id
      IO::ByteFormat::LittleEndian.encode(0x600000_u64, io) # user_data
      IO::ByteFormat::LittleEndian.encode(1_u64, io)        # user_data_type

      header = Cradare2::Engine::Godot::GodotObjectHeader.from_bytes(io.to_slice)
      header.vtable.should eq(0x401000_u64)
      header.instance_id.should eq(42_u64)
      header.user_data.should eq(0x600000_u64)
      header.user_data_type.should eq(1_u64)
      header.is_alive.should be_true
    end

    it "decodes Nil, Bool, Int, and Float Variants" do
      # Nil (type 0)
      nil_bytes = Bytes[0_u8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      v_nil = Cradare2::Engine::Godot::VariantDecoder.decode(nil_bytes)
      v_nil.type.should eq(Cradare2::Engine::Godot::VariantType::Nil)
      v_nil.value.should eq("nil")

      # Bool (type 1)
      bool_bytes = Bytes[1_u8, 0, 0, 0, 0, 0, 0, 0, 1_u8, 0, 0, 0, 0, 0, 0, 0]
      v_bool = Cradare2::Engine::Godot::VariantDecoder.decode(bool_bytes)
      v_bool.type.should eq(Cradare2::Engine::Godot::VariantType::Bool)
      v_bool.value.should eq("true")

      # Int (type 2, value 123456)
      int_io = IO::Memory.new
      int_io.write(Bytes[2_u8, 0, 0, 0, 0, 0, 0, 0])
      IO::ByteFormat::LittleEndian.encode(123456_i64, int_io)
      v_int = Cradare2::Engine::Godot::VariantDecoder.decode(int_io.to_slice)
      v_int.type.should eq(Cradare2::Engine::Godot::VariantType::Int)
      v_int.value.should eq("123456")

      # Float (type 3, value 3.14159)
      float_io = IO::Memory.new
      float_io.write(Bytes[3_u8, 0, 0, 0, 0, 0, 0, 0])
      IO::ByteFormat::LittleEndian.encode(3.14159_f64, float_io)
      v_float = Cradare2::Engine::Godot::VariantDecoder.decode(float_io.to_slice)
      v_float.type.should eq(Cradare2::Engine::Godot::VariantType::Float)
      v_float.value.to_f64.should be_close(3.14159, 0.0001)
    end

    it "decodes Vector2, Vector3, and Color Variants" do
      # Vector2 (type 5, x: 10.5, y: -20.5)
      v2_io = IO::Memory.new
      v2_io.write(Bytes[5_u8, 0, 0, 0, 0, 0, 0, 0])
      IO::ByteFormat::LittleEndian.encode(10.5_f32, v2_io)
      IO::ByteFormat::LittleEndian.encode(-20.5_f32, v2_io)
      v2 = Cradare2::Engine::Godot::VariantDecoder.decode(v2_io.to_slice)
      v2.type.should eq(Cradare2::Engine::Godot::VariantType::Vector2)
      v2.summary.should contain("10.5")
      v2.summary.should contain("-20.5")

      # Vector3 (type 9, x: 1.0, y: 2.0, z: 3.0)
      v3_io = IO::Memory.new
      v3_io.write(Bytes[9_u8, 0, 0, 0, 0, 0, 0, 0])
      IO::ByteFormat::LittleEndian.encode(1.0_f32, v3_io)
      IO::ByteFormat::LittleEndian.encode(2.0_f32, v3_io)
      IO::ByteFormat::LittleEndian.encode(3.0_f32, v3_io)
      v3 = Cradare2::Engine::Godot::VariantDecoder.decode(v3_io.to_slice)
      v3.type.should eq(Cradare2::Engine::Godot::VariantType::Vector3)
      v3.summary.should contain("1.0")
      v3.summary.should contain("2.0")
      v3.summary.should contain("3.0")

      # Color (type 20, r: 1.0, g: 0.0, b: 0.0, a: 1.0)
      col_io = IO::Memory.new
      col_io.write(Bytes[20_u8, 0, 0, 0, 0, 0, 0, 0])
      IO::ByteFormat::LittleEndian.encode(1.0_f32, col_io)
      IO::ByteFormat::LittleEndian.encode(0.0_f32, col_io)
      IO::ByteFormat::LittleEndian.encode(0.0_f32, col_io)
      IO::ByteFormat::LittleEndian.encode(1.0_f32, col_io)
      col = Cradare2::Engine::Godot::VariantDecoder.decode(col_io.to_slice)
      col.type.should eq(Cradare2::Engine::Godot::VariantType::Color)
      col.summary.should contain("Color(1.0, 0.0, 0.0, 1.0)")
    end

    it "decodes Object Variant" do
      obj_io = IO::Memory.new
      obj_io.write(Bytes[24_u8, 0, 0, 0, 0, 0, 0, 0])
      IO::ByteFormat::LittleEndian.encode(0x7FFE00102030_u64, obj_io)
      obj = Cradare2::Engine::Godot::VariantDecoder.decode(obj_io.to_slice)
      obj.type.should eq(Cradare2::Engine::Godot::VariantType::Object)
      obj.value.should eq("0x7ffe00102030")
    end

    it "reads Godot Object header and Variant via client shortcuts" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      # Build 32 bytes for Object header: vtable=0x401000, id=101, user_data=0x500000, udt=0
      hdr_io = IO::Memory.new
      IO::ByteFormat::LittleEndian.encode(0x401000_u64, hdr_io)
      IO::ByteFormat::LittleEndian.encode(101_u64, hdr_io)
      IO::ByteFormat::LittleEndian.encode(0x500000_u64, hdr_io)
      IO::ByteFormat::LittleEndian.encode(0_u64, hdr_io)

      json_bytes = hdr_io.to_slice.to_a.to_json
      mock.on("pxj 32 @ 0x450000", json_bytes)

      header = client.godot_object(0x450000_u64)
      header.vtable.should eq(0x401000_u64)
      header.instance_id.should eq(101_u64)
      header.user_data.should eq(0x500000_u64)
      header.is_alive.should be_true

      # Build 32 bytes for Variant (Int = 777)
      var_io = IO::Memory.new
      var_io.write(Bytes[2_u8, 0, 0, 0, 0, 0, 0, 0])
      IO::ByteFormat::LittleEndian.encode(777_i64, var_io)
      var_io.write(Bytes.new(16, 0_u8))
      mock.on("pxj 32 @ 0x460000", var_io.to_slice.to_a.to_json)

      variant = client.godot_variant(0x460000_u64)
      variant.type.should eq(Cradare2::Engine::Godot::VariantType::Int)
      variant.value.should eq("777")
    end

    it "registers Godot formats via types DSL" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      formats_registered = [] of String

      # Mock the format definitions
      mock.on("pf.godot_object qqqq vtable instance_id user_data user_data_type", "")
      mock.on("pf.godot_variant b...q type _pad payload", "")
      mock.on("pf.godot_vector2 ff x y", "")
      mock.on("pf.godot_vector2i ii x y", "")
      mock.on("pf.godot_vector3 fff x y z", "")
      mock.on("pf.godot_vector3i iii x y z", "")
      mock.on("pf.godot_vector4 ffff x y z w", "")
      mock.on("pf.godot_color ffff r g b a", "")
      mock.on("pf.godot_transform3d ffffffffffff xx xy xz yx yy yz zx zy zz ox oy oz", "")

      client.types.register_godot_formats!
    end
  end
end
