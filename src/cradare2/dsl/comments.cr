require "base64"
require "../address"

module Cradare2
  class Client
  end

  module DSL
    # Fluent DSL for setting, inspecting, and managing radare2 code comments safely.
    class Comments
      def initialize(@client : Client)
      end

      # Sets a comment at the specified address using Base64 encoding (`CCu <base64> @ <addr>`).
      # Completely prevents string escaping and shell injection issues with quotes or newlines.
      def set(address : Address, text : String) : self
        addr_str = AddressUtils.to_hex(address)
        encoded = Base64.strict_encode(text)
        @client.cmd("CCu #{encoded} @ #{addr_str}")
        self
      end

      # Batches setting multiple comments in a single pipe transaction.
      def batch_set(comments : Hash(Address, String)) : self
        return self if comments.empty?
        comments.each_slice(50) do |slice|
          cmds = slice.map do |addr, text|
            encoded = Base64.strict_encode(text)
            "CCu #{encoded} @ #{AddressUtils.to_hex(addr)}"
          end
          @client.cmd(cmds.join(";"))
        end
        self
      end

      # Retrieves the comment at the specified address, or nil if no comment is set (`CC. @ <addr>`).
      def get(address : Address) : String?
        addr_str = AddressUtils.to_hex(address)
        res = @client.cmd("CC. @ #{addr_str}").strip
        return nil if res.empty? || res.includes?("No comment")

        # If the comment was stored as Base64 by CCu, decode it
        if res.size >= 4 && res.size % 4 == 0 && res.matches?(/^[A-Za-z0-9+\/]+=*$/)
          begin
            decoded = Base64.decode_string(res)
            return decoded if decoded.valid_encoding?
          rescue
          end
        end
        res
      end

      # Removes the comment at the specified address (`CC- @ <addr>`).
      def clear(address : Address) : self
        addr_str = AddressUtils.to_hex(address)
        @client.cmd("CC- @ #{addr_str}")
        self
      end

      # Removes all comments throughout the binary session (`CC-*`).
      def clear_all : self
        @client.cmd("CC-*")
        self
      end

      # Returns all comments registered in the session as a mapping of Address => Comment text (`Cj`).
      def all : Hash(UInt64, String)
        result = Hash(UInt64, String).new
        begin
          res = @client.cmd("Cj").strip
          return result if res.empty? || res == "[]"
          parsed = JSON.parse(res)
          if arr = parsed.as_a?
            arr.each do |item|
              addr = item["offset"]?.try(&.as_i64?.try(&.to_u64)) || item["addr"]?.try(&.as_i64?.try(&.to_u64))
              text = item["name"]?.try(&.as_s?) || item["comment"]?.try(&.as_s?)
              if addr && text
                if text.size >= 4 && text.size % 4 == 0 && text.matches?(/^[A-Za-z0-9+\/]+=*$/)
                  begin
                    decoded = Base64.decode_string(text)
                    text = decoded if decoded.valid_encoding?
                  rescue
                  end
                end
                result[addr] = text
              end
            end
          end
        rescue
        end
        result
      end

      # Returns all comments as an array of (address, comment) tuples.
      def list : Array(Tuple(UInt64, String))
        all.to_a
      end
    end
  end
end
