require "./spec_helper"

describe "Memory Inspection & Crystal Runtime Structs Exhaustive Suite" do
  describe "DSL::Memory integer and float methods" do
    it "writes and reads 8-bit, 16-bit, 32-bit, and 64-bit integers" do
      executed = [] of String
      handler = ->(cmd : String) {
        executed << cmd
        case cmd
        when "pxj 1 @ 0x10" then "[42]"
        when "pxj 2 @ 0x20" then "[52, 18]"             # 0x1234
        when "pxj 4 @ 0x30" then "[239, 190, 173, 222]" # 0xdeadbeef
        when "pxj 8 @ 0x40" then "[239, 190, 173, 222, 0, 0, 0, 0]"
        else                     "[]"
        end
      }
      client = Cradare2.mock(handler)

      # 8-bit
      client.memory.write_u8(0x10, 42_u8)
      executed.last.should eq("wv1 42 @ 0x10")
      client.memory.read_u8(0x10).should eq(42_u8)

      client.memory.write_i8(0x10, -5_i8)
      executed.last.should eq("wv1 251 @ 0x10")

      # 16-bit
      client.memory.write_u16(0x20, 0x1234_u16)
      executed.last.should eq("wv2 4660 @ 0x20")
      client.memory.read_u16(0x20).should eq(0x1234_u16)

      client.memory.write_i16(0x20, -100_i16)
      executed.last.should eq("wv2 65436 @ 0x20")

      # 32-bit
      client.memory.write_u32(0x30, 0xdeadbeef_u32)
      executed.last.should eq("wv4 3735928559 @ 0x30")
      client.memory.read_u32(0x30).should eq(0xdeadbeef_u32)

      client.memory.write_i32(0x30, -1_i32)
      executed.last.should eq("wv4 4294967295 @ 0x30")

      # 64-bit
      client.memory.write_u64(0x40, 0xdeadbeef_u64)
      executed.last.should eq("wv8 3735928559 @ 0x40")
      client.memory.read_u64(0x40).should eq(0xdeadbeef_u64)

      client.memory.write_i64(0x40, -1_i64)
      executed.last.should eq("wv8 18446744073709551615 @ 0x40")
    end

    it "reads 32-bit and 64-bit IEEE 754 floats" do
      # 10.0_f32 in little endian: [0x00, 0x00, 0x20, 0x41] = [0, 0, 32, 65]
      # 20.0_f64 in little endian: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x34, 0x40] = [0, 0, 0, 0, 0, 0, 52, 64]
      handler = ->(cmd : String) {
        case cmd
        when "pxj 4 @ 0x100" then "[0, 0, 32, 65]"
        when "pxj 8 @ 0x200" then "[0, 0, 0, 0, 0, 0, 52, 64]"
        else                      "[]"
        end
      }
      client = Cradare2.mock(handler)

      client.memory.read_f32(0x100).should eq(10.0_f32)
      client.memory.read_f64(0x200).should eq(20.0_f64)
    end

    it "handles raw byte reading, hex reading, writing, and hexdumps" do
      executed = [] of String
      handler = ->(cmd : String) {
        executed << cmd
        case cmd
        when "pxj 4 @ 0x500" then "[1, 2, 3, 4]"
        when "p8 4 @ 0x500"  then "01020304"
        when "px 64 @ 0x500" then "0x00000500  0102 0304 ... hexdump"
        when "px 64"         then "0x00000000  ... hexdump default"
        else                      ""
        end
      }
      client = Cradare2.mock(handler)

      bytes = client.memory.read(0x500, 4)
      bytes.should eq(Bytes[1, 2, 3, 4])

      client.memory.read_hex(0x500, 4).should eq("01020304")

      client.memory.write(0x500, Bytes[0x90, 0x90])
      executed.last.should eq("wx 9090 @ 0x500")

      client.memory.write_hex(0x500, "cc")
      executed.last.should eq("wx cc @ 0x500")

      client.memory.write_string(0x500, "hello")
      executed.last.should eq("w hello @ 0x500")

      client.memory.hexdump(0x500).should contain("hexdump")
      client.memory.hexdump.should contain("hexdump default")
    end

    it "searches memory for byte sequences and strings" do
      handler = ->(cmd : String) {
        case cmd
        when "/x 9090"
          "0x140001000 hit 1\n0x140002500 hit 2\n"
        when "/ GodotEngine"
          "0x140008888 string match\n"
        else
          ""
        end
      }
      client = Cradare2.mock(handler)

      hits = client.memory.search_bytes(Bytes[0x90, 0x90])
      hits.should eq([0x140001000_u64, 0x140002500_u64])

      shits = client.memory.search_string("GodotEngine")
      shits.should eq([0x140008888_u64])
    end
  end

  describe "DSL::Memory #read_cstring and #read_pointer_array" do
    it "trims at escaped \\x00 null bytes from radare2 ps output" do
      handler = ->(cmd : String) {
        cmd.starts_with?("ps") ? "GodotEngine\\x00RandomGarbage" : ""
      }
      client = Cradare2.mock(handler)
      client.memory.read_cstring(0x1000).should eq("GodotEngine")
    end

    it "trims at literal null bytes from radare2 output" do
      handler = ->(cmd : String) {
        cmd.starts_with?("ps") ? "LapisPlugin\0Trailing" : ""
      }
      client = Cradare2.mock(handler)
      client.memory.read_cstring(0x2000).should eq("LapisPlugin")
    end

    it "handles empty string when first character is null" do
      handler = ->(cmd : String) {
        cmd.starts_with?("ps") ? "\\x00Garbage" : ""
      }
      client = Cradare2.mock(handler)
      client.memory.read_cstring(0x3000).should eq("")
    end

    it "falls back to byte slice search when ps returns empty" do
      handler = ->(cmd : String) {
        case cmd
        when "ps 256 @ 0x3500" then ""
        when "pxj 256 @ 0x3500"
          # "FallbackString\0"
          arr = "FallbackString".bytes + [0_u8] + [255_u8]*10
          arr.to_json
        else ""
        end
      }
      client = Cradare2.mock(handler)
      client.memory.read_cstring(0x3500).should eq("FallbackString")
    end

    it "reads arrays of 64-bit pointers" do
      # 2 pointers: 0x140001000 and 0x140002000
      # 0x140001000 little endian: [0, 16, 0, 64, 1, 0, 0, 0]
      # 0x140002000 little endian: [0, 32, 0, 64, 1, 0, 0, 0]
      p1 = [0, 16, 0, 64, 1, 0, 0, 0]
      p2 = [0, 32, 0, 64, 1, 0, 0, 0]
      handler = ->(cmd : String) {
        cmd == "pxj 16 @ 0x4000" ? (p1 + p2).to_json : "[]"
      }
      client = Cradare2.mock(handler)
      ptrs = client.memory.read_pointer_array(0x4000, count: 2)
      ptrs.size.should eq(2)
      ptrs[0].should eq(0x140001000_u64)
      ptrs[1].should eq(0x140002000_u64)
    end

    it "returns empty array when read_pointer_array count <= 0" do
      client = Cradare2.mock
      client.memory.read_pointer_array(0x4000, count: 0).should be_empty
      client.memory.read_pointer_array(0x4000, count: -5).should be_empty
    end
  end

  describe "CrystalHelper runtime object inspection" do
    it "reads a valid Crystal String struct" do
      handler = ->(cmd : String) {
        case cmd
        when "pxj 4 @ 0x1000"
          # offset 0: type_id (1)
          "[1, 0, 0, 0]"
        when "pxj 4 @ 0x1004"
          # offset 4: bytesize (5)
          "[5, 0, 0, 0]"
        when "pxj 4 @ 0x1008"
          # offset 8: length (5)
          "[5, 0, 0, 0]"
        when "pxj 5 @ 0x100c"
          # offset 12: "Hello"
          "Hello".bytes.to_json
        else
          "[]"
        end
      }
      client = Cradare2.mock(handler)
      str = client.crystal.read_string(0x1000)
      str.value.should eq("Hello")
      str.bytesize.should eq(5)
      str.length.should eq(5)

      # Also test convenience helper
      client.crystal.read_string_value(0x1000).should eq("Hello")
    end

    it "handles zero-length or negative bytesize Crystal String gracefully" do
      handler = ->(cmd : String) {
        case cmd
        when "pxj 4 @ 0x2000" then "[1, 0, 0, 0]"
        when "pxj 4 @ 0x2004" then "[0, 0, 0, 0]" # bytesize = 0
        when "pxj 4 @ 0x2008" then "[0, 0, 0, 0]" # length = 0
        when "pxj 4 @ 0x3000" then "[1, 0, 0, 0]"
        when "pxj 4 @ 0x3004" then "[255, 255, 255, 255]" # bytesize = -1 (corrupted)
        when "pxj 4 @ 0x3008" then "[0, 0, 0, 0]"
        else                       "[]"
        end
      }
      client = Cradare2.mock(handler)

      empty_str = client.crystal.read_string(0x2000)
      empty_str.value.should eq("")
      empty_str.bytesize.should eq(0)

      corrupted = client.crystal.read_string(0x3000)
      corrupted.value.should eq("")
      corrupted.bytesize.should eq(-1) # preserves raw bytesize field
    end

    it "reads a Crystal Array header" do
      handler = ->(cmd : String) {
        case cmd
        when "pxj 4 @ 0x4000" then "[1, 0, 0, 0]"              # type_id: 1
        when "pxj 4 @ 0x4004" then "[10, 0, 0, 0]"             # size: 10
        when "pxj 4 @ 0x4008" then "[16, 0, 0, 0]"             # capacity: 16
        when "pxj 8 @ 0x4010" then "[0, 0, 5, 64, 1, 0, 0, 0]" # buffer_addr: 0x140050000
        else                       "[]"
        end
      }
      client = Cradare2.mock(handler)
      arr = client.crystal.read_array_header(0x4000)
      arr.size.should eq(10)
      arr.capacity.should eq(16)
      arr.buffer_address.should eq(0x140050000_u64)
    end

    it "reads a Crystal Slice header" do
      handler = ->(cmd : String) {
        case cmd
        when "pxj 4 @ 0x5000" then "[100, 0, 0, 0]"            # size: 100
        when "pxj 1 @ 0x5004" then "[1]"                       # read_only: true
        when "pxj 8 @ 0x5008" then "[0, 0, 6, 64, 1, 0, 0, 0]" # pointer_addr: 0x140060000
        else                       "[]"
        end
      }
      client = Cradare2.mock(handler)
      slice = client.crystal.read_slice_header(0x5000)
      slice.size.should eq(100)
      slice.read_only?.should be_true
      slice.pointer_address.should eq(0x140060000_u64)
    end

    it "reads a Crystal Fiber struct" do
      handler = ->(cmd : String) {
        case cmd
        when "pxj 4 @ 0x6000" then "[42, 0, 0, 0]"                # type_id = 42
        when "pxj 1 @ 0x6004" then "[1]"                          # resumable = true
        when "pxj 4 @ 0x6008" then "[0, 32, 0, 0]"                # stack_size = 8192
        when "pxj 8 @ 0x6010" then "[0, 0, 254, 127, 0, 0, 0, 0]" # stack_address = 0x7ffe0000
        else                       "[]"
        end
      }
      client = Cradare2.mock(handler)
      fiber = client.crystal.read_fiber(0x6000)
      fiber.address.should eq(0x6000_u64)
      fiber.type_id.should eq(42)
      fiber.resumable?.should be_true
      fiber.stack_size.should eq(8192)
      fiber.stack_address.should eq(0x7ffe0000_u64)
    end

    it "reads a Crystal Hash header" do
      handler = ->(cmd : String) {
        case cmd
        when "pxj 4 @ 0x7000" then "[5, 0, 0, 0]"  # type_id = 5
        when "pxj 4 @ 0x7004" then "[16, 0, 0, 0]" # size = 16
        when "pxj 4 @ 0x7008" then "[32, 0, 0, 0]" # capacity = 32
        else                       "[]"
        end
      }
      client = Cradare2.mock(handler)
      hash = client.crystal.read_hash_header(0x7000)
      hash.address.should eq(0x7000_u64)
      hash.type_id.should eq(5)
      hash.size.should eq(16)
      hash.capacity.should eq(32)
    end
  end
end
