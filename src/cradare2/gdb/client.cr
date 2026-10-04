require "socket"

module Cradare2
  module Gdb
    # Lightweight, standalone GDB Remote Serial Protocol (RSP) client over TCP.
    # Allows zero-dependency memory querying, register inspection, and hardware canary checks
    # directly against PCSX2, QEMU, or gdbserver without spawning a radare2 process.
    class Client
      getter host : String
      getter port : Int32
      getter socket : TCPSocket?

      def initialize(@host : String = "127.0.0.1", @port : Int32 = 1234)
      end

      # Computes the 8-bit modulo 256 checksum for a GDB RSP payload.
      def self.calculate_checksum(payload : String) : UInt8
        csum = 0_u8
        payload.each_byte do |b|
          csum = csum &+ b
        end
        csum
      end

      # Formats a command string into a complete GDB packet with start mark '$' and checksum.
      def self.format_packet(payload : String) : String
        csum = calculate_checksum(payload)
        sprintf("$%s#%02x", payload, csum)
      end

      # Connects to the remote GDB stub.
      def connect : Bool
        begin
          s = TCPSocket.new(@host, @port)
          s.sync = true
          @socket = s
          # Send initial ack
          s.write_byte('+'.ord.to_u8)
          true
        rescue ex
          false
        end
      end

      # Returns true if the client socket is active.
      def connected? : Bool
        !@socket.nil? && !@socket.not_nil!.closed?
      end

      # Closes the connection.
      def close : Nil
        @socket.try(&.close) rescue nil
        @socket = nil
      end

      # Sends a command payload and reads the response packet.
      def send_command(payload : String) : String
        s = @socket
        return "" unless s

        packet = Client.format_packet(payload)
        s.print(packet)
        s.flush

        # Wait for ack '+'
        ack = s.read_byte
        return "" unless ack == '+'.ord

        # Read response
        read_packet
      end

      # Reads memory of `length` bytes from target `address`.
      def read_memory(address : UInt64, length : Int32) : Bytes?
        return nil if length <= 0
        cmd = sprintf("m%x,%x", address, length)
        resp = send_command(cmd)
        return nil if resp.empty? || resp.starts_with?("E")

        # Response is hex-encoded bytes: 2 hex characters per byte
        expected_hex_chars = length * 2
        return nil if resp.size < expected_hex_chars

        bytes = Bytes.new(length)
        length.times do |i|
          hex = resp[i * 2, 2]
          if val = hex.to_u8?(16)
            bytes[i] = val
          else
            return nil
          end
        end
        bytes
      end

      # Reads a 32-bit integer directly from memory.
      def read_u32(address : UInt64, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : UInt32?
        bytes = read_memory(address, 4)
        return nil unless bytes && bytes.size == 4
        format.decode(UInt32, bytes)
      end

      # Reads a 64-bit integer directly from memory.
      def read_u64(address : UInt64, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : UInt64?
        bytes = read_memory(address, 8)
        return nil unless bytes && bytes.size == 8
        format.decode(UInt64, bytes)
      end

      # Reads a 128-bit integer (PS2 EE QWORD) directly from memory.
      def read_u128(address : UInt64, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : UInt128?
        bytes = read_memory(address, 16)
        return nil unless bytes && bytes.size == 16
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

      private def read_packet : String
        s = @socket
        return "" unless s

        buf = IO::Memory.new
        in_packet = false

        while byte = s.read_byte
          char = byte.chr
          if char == '$'
            in_packet = true
            next
          elsif char == '#' && in_packet
            # Read 2 checksum bytes
            s.read_byte
            s.read_byte
            # Send ack
            s.write_byte('+'.ord.to_u8)
            s.flush
            break
          elsif in_packet
            buf << char
          end
        end

        buf.to_s
      end
    end
  end
end
