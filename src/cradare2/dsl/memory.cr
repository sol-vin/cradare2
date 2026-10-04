require "../address"

module Cradare2
  module DSL
    # DSL for memory inspection, reading, writing, and byte pattern searching.
    class Memory
      def initialize(@client : Client)
      end

      # Formats address as string
      private def addr_s(address : Address) : String
        AddressUtils.to_hex(address)
      end

      # Reads raw bytes from address as a Crystal `Bytes` slice.
      def read(address : Address, size : Int32) : Bytes
        cmd_str = "pxj #{size} @ #{addr_s(address)}"
        arr = @client.cmdj(cmd_str).as_a
        slice = Bytes.new(arr.size)
        arr.each_with_index do |v, i|
          slice[i] = v.as_i.to_u8
        end
        slice
      rescue
        Bytes.empty
      end

      # Alias for `read`.
      def read_bytes(address : Address, size : Int32) : Bytes
        read(address, size)
      end

      # Reads bytes formatted as a continuous hex string.
      def read_hex(address : Address, size : Int32) : String
        @client.cmd("p8 #{size} @ #{addr_s(address)}").strip
      end

      # Reads a null-terminated C string from memory address.
      def read_string(address : Address, max_len : Int32? = nil) : String
        cmd_str = max_len ? "ps #{max_len} @ #{addr_s(address)}" : "ps @ #{addr_s(address)}"
        @client.cmd(cmd_str).strip
      end

      # Reads a null-terminated UTF-8 C-string from memory with fallback to byte search.
      def read_cstring(address : Address, max_len : Int32 = 256) : String
        cmd_str = "ps #{max_len} @ #{addr_s(address)}"
        res = @client.cmd(cmd_str).strip
        unless res.empty?
          # Radare2 ps escapes null bytes as \x00 or \0
          if split_idx = res.index("\\x00")
            return res[0...split_idx]
          elsif split_idx = res.index('\0')
            return res[0...split_idx]
          end
          return res
        end

        bytes = read_bytes(address, max_len)
        return "" if bytes.empty?
        if null_idx = bytes.index(0_u8)
          String.new(bytes[0...null_idx])
        else
          String.new(bytes)
        end
      end

      # Reads an array of 64-bit pointers (ideal for vtables, dispatch tables, and StringName literals).
      def read_pointer_array(address : Address, count : Int32) : Array(UInt64)
        return [] of UInt64 if count <= 0
        bytes = read_bytes(address, count * 8)
        pointers = Array(UInt64).new(count)
        (0...count).each do |i|
          offset = i * 8
          if offset + 8 <= bytes.size
            slice = bytes[offset, 8]
            pointers << IO::ByteFormat::LittleEndian.decode(UInt64, slice)
          else
            pointers << 0_u64
          end
        end
        pointers
      end

      # Reads unsigned integers of various bit widths.
      def read_u8(address : Address) : UInt8
        bytes = read(address, 1)
        bytes.size >= 1 ? bytes[0] : 0_u8
      end

      def read_u16(address : Address, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : UInt16
        bytes = read(address, 2)
        return 0_u16 if bytes.size < 2
        format.decode(UInt16, bytes)
      end

      def read_u32(address : Address, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : UInt32
        bytes = read(address, 4)
        return 0_u32 if bytes.size < 4
        format.decode(UInt32, bytes)
      end

      def read_u64(address : Address, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : UInt64
        bytes = read(address, 8)
        return 0_u64 if bytes.size < 8
        format.decode(UInt64, bytes)
      end

      # Reads a 128-bit unsigned integer (Emotion Engine QWORD).
      def read_u128(address : Address, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : UInt128
        bytes = read(address, 16)
        return 0_u128 if bytes.size < 16
        if format == IO::ByteFormat::BigEndian
          high = format.decode(UInt64, bytes[0, 8])
          low = format.decode(UInt64, bytes[8, 8])
          (UInt128.new(high) << 64) | UInt128.new(low)
        else
          low = format.decode(UInt64, bytes[0, 8])
          high = format.decode(UInt64, bytes[8, 8])
          UInt128.new(low) | (UInt128.new(high) << 64)
        end
      end

      # Alias for read_u128.
      def read_qword(address : Address, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : UInt128
        read_u128(address, format)
      end

      # Reads signed integers of various bit widths.
      def read_i8(address : Address) : Int8
        read_u8(address).to_i8!
      end

      def read_i16(address : Address, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : Int16
        read_u16(address, format).to_i16!
      end

      def read_i32(address : Address, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : Int32
        read_u32(address, format).to_i32!
      end

      def read_i64(address : Address, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : Int64
        read_u64(address, format).to_i64!
      end

      def read_i128(address : Address, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : Int128
        read_u128(address, format).to_i128!
      end

      # Reads floating-point numbers.
      def read_f32(address : Address, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : Float32
        bytes = read(address, 4)
        return 0.0_f32 if bytes.size < 4
        format.decode(Float32, bytes)
      end

      def read_f64(address : Address, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : Float64
        bytes = read(address, 8)
        return 0.0_f64 if bytes.size < 8
        format.decode(Float64, bytes)
      end

      # Reads an array of 32-bit pointers (ideal for 32-bit targets like PS2 MIPS).
      def read_pointer32_array(address : Address, count : Int32, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : Array(UInt32)
        return [] of UInt32 if count <= 0
        bytes = read_bytes(address, count * 4)
        pointers = Array(UInt32).new(count)
        (0...count).each do |i|
          offset = i * 4
          if offset + 4 <= bytes.size
            pointers << format.decode(UInt32, bytes[offset, 4])
          else
            pointers << 0_u32
          end
        end
        pointers
      end

      # Reads an array of 8-bit unsigned integers.
      def read_u8_array(address : Address, count : Int32) : Array(UInt8)
        return [] of UInt8 if count <= 0
        read_bytes(address, count).to_a
      end

      # Reads an array of 32-bit unsigned integers.
      def read_u32_array(address : Address, count : Int32, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : Array(UInt32)
        return [] of UInt32 if count <= 0
        bytes = read_bytes(address, count * 4)
        result = Array(UInt32).new(count)
        (0...count).each do |i|
          offset = i * 4
          if offset + 4 <= bytes.size
            result << format.decode(UInt32, bytes[offset, 4])
          else
            result << 0_u32
          end
        end
        result
      end

      # Reads an array of 64-bit unsigned integers.
      def read_u64_array(address : Address, count : Int32, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : Array(UInt64)
        return [] of UInt64 if count <= 0
        bytes = read_bytes(address, count * 8)
        result = Array(UInt64).new(count)
        (0...count).each do |i|
          offset = i * 8
          if offset + 8 <= bytes.size
            result << format.decode(UInt64, bytes[offset, 8])
          else
            result << 0_u64
          end
        end
        result
      end

      # Reads an array of 32-bit IEEE 754 floating point numbers.
      def read_f32_array(address : Address, count : Int32, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : Array(Float32)
        return [] of Float32 if count <= 0
        bytes = read_bytes(address, count * 4)
        result = Array(Float32).new(count)
        (0...count).each do |i|
          offset = i * 4
          if offset + 4 <= bytes.size
            result << format.decode(Float32, bytes[offset, 4])
          else
            result << 0.0_f32
          end
        end
        result
      end

      # Writes a slice of bytes to the given address using `wx`.
      def write(address : Address, bytes : Bytes) : self
        hex_str = bytes.hexstring
        write_hex(address, hex_str)
        self
      end

      # Writes hex characters directly (e.g. "909090" for NOPs).
      def write_hex(address : Address, hex : String) : self
        @client.cmd("wx #{hex} @ #{addr_s(address)}")
        self
      end

      # Writes a string to the given address.
      def write_string(address : Address, string : String) : self
        @client.cmd("w #{string} @ #{addr_s(address)}")
        self
      end

      # Writes an 8-bit unsigned integer.
      def write_u8(address : Address, value : UInt8) : self
        @client.cmd("wv1 #{value} @ #{addr_s(address)}")
        self
      end

      def write_i8(address : Address, value : Int8) : self
        write_u8(address, value.to_u8!)
      end

      # Writes a 16-bit unsigned integer.
      def write_u16(address : Address, value : UInt16) : self
        @client.cmd("wv2 #{value} @ #{addr_s(address)}")
        self
      end

      def write_i16(address : Address, value : Int16) : self
        write_u16(address, value.to_u16!)
      end

      # Writes a 32-bit integer.
      def write_u32(address : Address, value : UInt32) : self
        @client.cmd("wv4 #{value} @ #{addr_s(address)}")
        self
      end

      def write_i32(address : Address, value : Int32) : self
        write_u32(address, value.to_u32!)
      end

      # Writes a 64-bit integer.
      def write_u64(address : Address, value : UInt64) : self
        @client.cmd("wv8 #{value} @ #{addr_s(address)}")
        self
      end

      def write_i64(address : Address, value : Int64) : self
        write_u64(address, value.to_u64!)
      end

      # Writes a 128-bit unsigned integer (Emotion Engine QWORD).
      def write_u128(address : Address, value : UInt128, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : self
        slice = Bytes.new(16)
        low = (value & 0xFFFFFFFFFFFFFFFF_u128).to_u64
        high = ((value >> 64) & 0xFFFFFFFFFFFFFFFF_u128).to_u64
        if format == IO::ByteFormat::BigEndian
          format.encode(high, slice[0, 8])
          format.encode(low, slice[8, 8])
        else
          format.encode(low, slice[0, 8])
          format.encode(high, slice[8, 8])
        end
        write(address, slice)
      end

      # Alias for write_u128.
      def write_qword(address : Address, value : UInt128, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : self
        write_u128(address, value, format)
      end

      def write_i128(address : Address, value : Int128, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : self
        write_u128(address, value.to_u128!, format)
      end

      # Returns formatted hexdump text for human inspection.
      def hexdump(address : Address? = nil, size : Int32 = 64) : String
        cmd_str = address ? "px #{size} @ #{addr_s(address)}" : "px #{size}"
        @client.cmd(cmd_str)
      end

      # Searches memory for a hex string pattern, allowing optional spaces (e.g. "48 89 5c 24").
      def search_hex(hex_pattern : String) : Array(UInt64)
        clean = hex_pattern.gsub(/\s+/, "")
        search_output = @client.cmd("/x #{clean}")
        parse_search_offsets(search_output)
      end

      # Compares memory between two addresses and returns diff output.
      def hexdiff(address1 : Address, address2 : Address, size : Int32 = 64) : String
        @client.cmd("cc #{size} @ #{addr_s(address2)} @ #{addr_s(address1)}")
      end

      # Searches memory for a byte pattern (e.g. Bytes[0x48, 0x89]).
      def search_bytes(bytes : Bytes) : Array(UInt64)
        hex = bytes.hexstring
        search_output = @client.cmd("/x #{hex}")
        parse_search_offsets(search_output)
      end

      # Searches memory for a string query.
      def search_string(query : String) : Array(UInt64)
        search_output = @client.cmd("/ #{query}")
        parse_search_offsets(search_output)
      end

      private def parse_search_offsets(output : String) : Array(UInt64)
        results = [] of UInt64
        output.each_line do |line|
          line = line.strip
          # radare2 search outputs lines starting with 0x...
          if line.starts_with?("0x")
            parts = line.split
            if hex_addr = parts.first?
              if val = hex_addr[2..].to_u64?(16)
                results << val
              end
            end
          end
        end
        results
      end
    end
  end
end
