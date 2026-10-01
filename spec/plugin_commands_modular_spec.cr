require "./spec_helper"

describe "Modular Plugin Commands Exhaustive Suite" do
  describe "DetectCommand" do
    it "detects Crystal binary when entrypoint and symbols are present" do
      handler = ->(cmd : String) {
        case cmd
        when "isj" then %([{"name":"__crystal_main","vaddr":4096,"type":"FUNC"}])
        else            "[]"
        end
      }
      client = Cradare2.mock(handler)
      cmd = Cradare2::Plugin::Commands::DetectCommand.new

      cmd.name.should eq("detect")
      res = cmd.execute(client, [] of String)
      res.should contain("Target is a Crystal binary!")
      res.should contain("0x1000")

      res_j = cmd.execute(client, [] of String, json: true)
      json = JSON.parse(res_j)
      json["crystal"].as_bool.should be_true
      json["entrypoint"].as_i64.should eq(0x1000)
    end

    it "reports negative when target is not a Crystal binary" do
      client = Cradare2.mock
      cmd = Cradare2::Plugin::Commands::DetectCommand.new
      res = cmd.execute(client, [] of String)
      res.should contain("Target does NOT appear to be a Crystal binary.")

      res_j = cmd.execute(client, [] of String, json: true)
      JSON.parse(res_j)["crystal"].as_bool.should be_false
    end
  end

  describe "InfoCommand" do
    it "emits formatted and JSON target info" do
      handler = ->(cmd : String) {
        case cmd
        when "isj"
          %([{"name":"__crystal_main","vaddr":4096,"type":"FUNC"}])
        when "aflj"
          %([{"name":"GC_malloc","offset":8192,"size":64}])
        else "[]"
        end
      }
      client = Cradare2.mock(handler)
      cmd = Cradare2::Plugin::Commands::InfoCommand.new

      res = cmd.execute(client, [] of String)
      res.should contain("=== Crystal Target Info ===")
      res.should contain("Entrypoint (__crystal_main): 0x1000")
      res.should contain("Boehm GC Functions: 1 found")

      res_j = cmd.execute(client, [] of String, json: true)
      json = JSON.parse(res_j)
      json["crystal_binary"].as_bool.should be_true
      json["entrypoint"].as_i64.should eq(0x1000)
      json["gc_functions"].as_i.should eq(1)
    end
  end

  describe "DemangleCommand and DemangleAllCommand" do
    it "validates arguments and demangles a single symbol" do
      client = Cradare2.mock
      cmd = Cradare2::Plugin::Commands::DemangleCommand.new

      cmd.execute(client, [] of String).should contain("Usage: crystal demangle")
      JSON.parse(cmd.execute(client, [] of String, json: true))["error"].as_s.should contain("Usage")

      res = cmd.execute(client, ["*MyModule::MyClass#hello:Int32"])
      res.should contain("->")
      res.should contain("MyModule::MyClass#hello")

      res_j = cmd.execute(client, ["*MyModule::MyClass#hello:Int32"], json: true)
      json = JSON.parse(res_j)
      json["symbol"].as_s.should eq("*MyModule::MyClass#hello:Int32")
      json["demangled"].as_s.should contain("MyModule::MyClass#hello")
    end

    it "demangles all functions in radare2 session" do
      handler = ->(cmd : String) {
        case cmd
        when "aflj"
          %([{"name":"*App::run:Nil","offset":4096,"size":32}])
        else ""
        end
      }
      client = Cradare2.mock(handler)
      cmd = Cradare2::Plugin::Commands::DemangleAllCommand.new
      cmd.aliases.should contain("demangle_all")

      res = cmd.execute(client, [] of String)
      res.should contain("Demangled and renamed 1 functions/symbols")

      res_j = cmd.execute(client, [] of String, json: true)
      json = JSON.parse(res_j)
      json["demangled_count"].as_i.should eq(1)
      json["renamed"]["0x1000"].as_s.should eq("App::run:Nil")
    end
  end

  describe "ClassesCommand and MethodsCommand" do
    it "lists discovered Crystal classes" do
      handler = ->(cmd : String) {
        case cmd
        when "aflj"
          %([
            {"name":"*Player::move:Nil","offset":4096,"size":16},
            {"name":"*Enemy::spawn:Nil","offset":8192,"size":16}
          ])
        else "[]"
        end
      }
      client = Cradare2.mock(handler)
      cmd = Cradare2::Plugin::Commands::ClassesCommand.new

      res = cmd.execute(client, [] of String)
      res.should contain("Discovered Crystal Classes/Modules (2):")
      res.should contain("Player")
      res.should contain("Enemy")

      res_j = cmd.execute(client, [] of String, json: true)
      json = JSON.parse(res_j)
      json["count"].as_i.should eq(2)
      json["classes"].as_a.map(&.as_s).should eq(["Enemy", "Player"])
    end

    it "lists methods for a given class or reports empty" do
      handler = ->(cmd : String) {
        case cmd
        when "aflj"
          %([{"name":"*Player::attack:Int32","offset":4096,"size":24}])
        when "isj"
          "[]"
        else "[]"
        end
      }
      client = Cradare2.mock(handler)
      cmd = Cradare2::Plugin::Commands::MethodsCommand.new

      cmd.execute(client, [] of String).should contain("Usage: crystal methods")

      res = cmd.execute(client, ["Player"])
      res.should contain("Methods for Player (1):")
      res.should contain("Player::attack")

      res_j = cmd.execute(client, ["Player"], json: true)
      json = JSON.parse(res_j)
      json["class"].as_s.should eq("Player")
      json["methods"].as_a.size.should eq(1)

      res_empty = cmd.execute(client, ["NonExistent"])
      res_empty.should contain("No methods found for class 'NonExistent'.")
    end
  end

  describe "InspectCommand" do
    it "inspects Crystal String, Array, and Slice structures" do
      handler = ->(cmd : String) {
        case cmd
        when "pxj 4 @ 0x1000" then "[1, 0, 0, 0]"
        when "pxj 4 @ 0x1004" then "[4, 0, 0, 0]"
        when "pxj 4 @ 0x1008" then "[4, 0, 0, 0]"
        when "pxj 4 @ 0x100c" then "Test".bytes.to_json
        when "pxj 4 @ 0x2000" then "[2, 0, 0, 0]"
        when "pxj 4 @ 0x2004" then "[5, 0, 0, 0]"
        when "pxj 4 @ 0x2008" then "[8, 0, 0, 0]"
        when "pxj 8 @ 0x2010" then "[0, 0, 1, 64, 1, 0, 0, 0]" # 0x140010000
        when "pxj 4 @ 0x3000" then "[50, 0, 0, 0]"
        when "pxj 1 @ 0x3004" then "[0]"
        when "pxj 8 @ 0x3008" then "[0, 0, 2, 64, 1, 0, 0, 0]" # 0x140020000
        else                       "[]"
        end
      }
      client = Cradare2.mock(handler)
      cmd = Cradare2::Plugin::Commands::InspectCommand.new

      # String
      str_res = cmd.execute(client, ["string", "0x1000"])
      str_res.should contain("Crystal String @ 0x1000:")
      str_res.should contain("value:    \"Test\"")

      str_j = cmd.execute(client, ["str", "0x1000"], json: true)
      JSON.parse(str_j)["value"].as_s.should eq("Test")

      # Array
      arr_res = cmd.execute(client, ["array", "0x2000"])
      arr_res.should contain("Crystal Array(T) @ 0x2000:")
      arr_res.should contain("size:     5")

      arr_j = cmd.execute(client, ["arr", "0x2000"], json: true)
      JSON.parse(arr_j)["size"].as_i.should eq(5)

      # Slice
      sl_res = cmd.execute(client, ["slice", "0x3000"])
      sl_res.should contain("Crystal Slice(T) @ 0x3000:")
      sl_res.should contain("size:      50")

      sl_j = cmd.execute(client, ["slice", "0x3000"], json: true)
      JSON.parse(sl_j)["size"].as_i.should eq(50)

      # Validation errors
      cmd.execute(client, [] of String).should contain("Usage: crystal inspect")
      cmd.execute(client, ["string", "invalid_hex"]).should contain("Invalid address")
      cmd.execute(client, ["unknown_type", "0x1000"]).should contain("Unknown inspect type")
    end
  end

  describe "CrashCommand" do
    it "generates demangled crash diagnostics and JSON crash info" do
      handler = ->(cmd : String) {
        case cmd
        when "drj"
          %({"rip":4096,"rsp":8192,"rax":0,"rbx":0,"rcx":0,"rdx":0,"rsi":0,"rdi":0,"rbp":0,"r8":0,"r9":0,"r10":0,"r11":0,"r12":0,"r13":0,"r14":0,"r15":0,"rflags":0})
        when "dbtj"
          %([{"frame":0,"addr":4096,"sp":8192,"function":"*Player::crash:Nil"}])
        when "dmj"
          %([{"addr":0,"addr_end":4095,"name":"unmapped","perm":"---"}])
        when "pdj 1 @ 0x1000"
          %([{"offset":4096,"size":3,"opcode":"mov [rax], 1","bytes":"48c70001"}])
        else ""
        end
      }
      client = Cradare2.mock(handler)
      cmd = Cradare2::Plugin::Commands::CrashCommand.new

      res = cmd.execute(client, [] of String)
      res.should contain("Crystal Target Crash / Debug Report")
      res.should contain("Player::crash")

      res_j = cmd.execute(client, [] of String, json: true)
      json = JSON.parse(res_j)
      json["faulting_address"].as_s.should eq("0x1000")
      json["probable_cause"].as_s.should_not be_empty
    end
  end

  describe "LinesCommand, SourceCommand, AsmCommand, and InterleavedCommand" do
    it "handles lines sync, lines address lookup, and lines function lookup" do
      executed = [] of String
      handler = ->(cmd : String) {
        executed << cmd
        case cmd
        when "CLj"
          %([{"addr":4096,"file":"game.cr","line":15,"colu":0}])
        else ""
        end
      }
      client = Cradare2.mock(handler)
      cmd = Cradare2::Plugin::Commands::LinesCommand.new

      # Lines sync
      sync_res = cmd.execute(client, ["sync"])
      sync_res.should contain("Synchronized")
      sync_j = cmd.execute(client, ["sync"], json: true)
      JSON.parse(sync_j)["synchronized"].as_i.should be >= 0

      # Lines address lookup
      client.crystal.lines.map.add(0x1000_u64, "game.cr", 15, opcode: "nop")
      addr_res = cmd.execute(client, ["0x1000"])
      addr_res.should contain("0x1000 -> game.cr:15")

      addr_j = cmd.execute(client, ["0x1000"], json: true)
      JSON.parse(addr_j)["file"].as_s.should eq("game.cr")
      JSON.parse(addr_j)["line"].as_i.should eq(15)

      # Unmapped address
      cmd.execute(client, ["0x9999"]).should contain("No source mapping found")
    end

    it "displays source code context around instruction via SourceCommand" do
      client = Cradare2.mock
      client.crystal.lines.reader.register_source("game.cr", "def play\n  run_loop\nend")
      client.crystal.lines.map.add(0x1000_u64, "game.cr", 2, opcode: "call run_loop")

      cmd = Cradare2::Plugin::Commands::SourceCommand.new
      cmd.aliases.should contain("source")

      res = cmd.execute(client, ["0x1000"])
      res.should contain("=== game.cr:2 (0x1000) ===")
      res.should contain("run_loop")

      res_j = cmd.execute(client, ["0x1000"], json: true)
      json = JSON.parse(res_j)
      json["file"].as_s.should eq("game.cr")
      json["line"].as_i.should eq(2)
      json["context"].as_a.size.should be > 0
    end

    it "displays machine instructions for source line via AsmCommand" do
      client = Cradare2.mock
      client.crystal.lines.map.add(0x1000_u64, "game.cr", 10, opcode: "xor eax, eax", bytes: "31c0")
      client.crystal.lines.map.add(0x1002_u64, "game.cr", 10, opcode: "ret", bytes: "c3")

      cmd = Cradare2::Plugin::Commands::AsmCommand.new

      res = cmd.execute(client, ["game.cr:10"])
      res.should contain("Instructions for game.cr:10 (2 insts):")
      res.should contain("xor eax, eax")
      res.should contain("ret")

      res_j = cmd.execute(client, ["game.cr:10"], json: true)
      json = JSON.parse(res_j)
      json["count"].as_i.should eq(2)
      json["instructions"].as_a[0]["opcode"].as_s.should eq("xor eax, eax")

      # Validation errors
      cmd.execute(client, [] of String).should contain("Usage: crystal asm")
      cmd.execute(client, ["game.cr"]).should contain("Invalid format")
      cmd.execute(client, ["game.cr:not_a_num"]).should contain("Invalid line number")
      cmd.execute(client, ["game.cr:999"]).should contain("No instructions found")
    end

    it "displays interleaved source and assembly via InterleavedCommand" do
      client = Cradare2.mock
      client.crystal.lines.reader.register_source("game.cr", "def foo\n  ret\nend")
      client.crystal.lines.map.add(0x1000_u64, "game.cr", 2, opcode: "ret", function_name: "foo")

      cmd = Cradare2::Plugin::Commands::InterleavedCommand.new
      cmd.aliases.should contain("il")

      res = cmd.execute(client, ["foo"])
      res.should contain("File: game.cr")

      res_j = cmd.execute(client, ["foo"], json: true)
      json = JSON.parse(res_j)
      json["target"].as_s.should eq("foo")
      json["groups"].as_a.size.should eq(1)

      cmd.execute(client, [] of String).should contain("Usage: crystal interleaved")
    end
  end
end
