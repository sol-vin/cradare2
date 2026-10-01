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

      def read_u16(address : Address) : UInt16
        bytes = read(address, 2)
        return 0_u16 if bytes.size < 2
        IO::ByteFormat::LittleEndian.decode(UInt16, bytes)
      end

      def read_u32(address : Address) : UInt32
        bytes = read(address, 4)
        return 0_u32 if bytes.size < 4
        IO::ByteFormat::LittleEndian.decode(UInt32, bytes)
      end

      def read_u64(address : Address) : UInt64
        bytes = read(address, 8)
        return 0_u64 if bytes.size < 8
        IO::ByteFormat::LittleEndian.decode(UInt64, bytes)
      end

      # Reads signed integers of various bit widths.
      def read_i8(address : Address) : Int8
        read_u8(address).to_i8!
      end

      def read_i16(address : Address) : Int16
        read_u16(address).to_i16!
      end

      def read_i32(address : Address) : Int32
        read_u32(address).to_i32!
      end

      def read_i64(address : Address) : Int64
        read_u64(address).to_i64!
      end

      # Reads floating-point numbers.
      def read_f32(address : Address) : Float32
        bytes = read(address, 4)
        return 0.0_f32 if bytes.size < 4
        IO::ByteFormat::LittleEndian.decode(Float32, bytes)
      end

      def read_f64(address : Address) : Float64
        bytes = read(address, 8)
        return 0.0_f64 if bytes.size < 8
        IO::ByteFormat::LittleEndian.decode(Float64, bytes)
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

      # Returns formatted hexdump text for human inspection.
      def hexdump(address : Address? = nil, size : Int32 = 64) : String
        cmd_str = address ? "px #{size} @ #{addr_s(address)}" : "px #{size}"
        @client.cmd(cmd_str)
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
