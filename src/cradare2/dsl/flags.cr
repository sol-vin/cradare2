require "../models/flag"
require "../address"

module Cradare2
  class Client
  end

  module DSL
    # Fluent DSL for managing radare2 flags (symbols, labels, markers).
    class Flags
      def initialize(@client : Client)
      end

      # Sets a flag at the given address with an optional size in bytes (`f <name> <size> @ <address>`).
      def set(name : String, address : Address, size : UInt64 = 0_u64) : self
        addr_str = AddressUtils.to_hex(address)
        if size > 0
          @client.cmd("f #{name} #{size} #{addr_str}")
        else
          @client.cmd("f #{name} @ #{addr_str}")
        end
        self
      end

      # Retrieves the virtual address for a named flag, or nil if not found (`f? <name>` / `fj`).
      def get(name : String) : UInt64?
        res = @client.cmd("?v #{name}").strip
        if res.starts_with?("0x") || res.starts_with?("0X")
          val = res[2..].to_u64?(16)
          return val if val && val > 0
        elsif val = res.to_u64?
          return val if val > 0
        end

        # Fallback query flag table
        flags = matching(name)
        flags.find { |f| f.name == name }.try(&.offset)
      end

      # Deletes a flag by name (`f- <name>`).
      def delete(name : String) : self
        @client.cmd("f- #{name}")
        self
      end

      # Renames an existing flag (`fr <old> <new>`).
      def rename(old_name : String, new_name : String) : self
        @client.cmd("fr #{old_name} #{new_name}")
        self
      end

      # Returns all defined flags in the session (`fj`).
      def all : Array(Model::Flag)
        begin
          @client.cmdj("fj", as: Array(Model::Flag))
        rescue
          [] of Model::Flag
        end
      end

      # Filters flags matching a string query or regular expression.
      def matching(pattern : String | Regex) : Array(Model::Flag)
        all.select do |flag|
          case pattern
          when Regex
            pattern.matches?(flag.name) || (flag.realname ? pattern.matches?(flag.realname.not_nil!) : false)
          when String
            flag.name.includes?(pattern) || (flag.realname ? flag.realname.not_nil!.includes?(pattern) : false)
          else
            false
          end
        end
      end

      # Batches the creation of multiple flags in a single command pipeline (`f name @ addr; ...`).
      def batch_set(flags : Hash(String, Address)) : self
        return self if flags.empty?
        # Chunk into groups of 50 to avoid exceeding shell buffer limits
        flags.each_slice(50) do |slice|
          cmds = slice.map do |name, addr|
            "f #{name} @ #{AddressUtils.to_hex(addr)}"
          end
          @client.cmd(cmds.join(";"))
        end
        self
      end

      # Selects or creates a flag space (`fs <name>`).
      def space(name : String) : self
        @client.cmd("fs #{name}")
        self
      end

      # Selects a flag space for the duration of the block, restoring the previous space afterwards.
      def space(name : String, &block : Flags -> U) : U forall U
        old = current_space
        space(name)
        begin
          yield self
        ensure
          if old.empty? || old == "*"
            clear_space
          else
            space(old)
          end
        end
      end

      # Executes the block within the designated flag space, safely restoring the previous space.
      def in_space(name : String, &block : Flags -> U) : U forall U
        space(name, &block)
      end

      # Returns the name of the currently active flag space (`fs.`).
      def current_space : String
        @client.cmd("fs.").strip
      end

      # Returns all defined flag spaces in the session (`fs`).
      def spaces : Array(String)
        output = @client.cmd("fs").strip
        result = [] of String
        output.each_line do |line|
          line = line.strip
          next if line.empty?
          parts = line.split(/\s+/)
          if space_name = parts.last?
            result << space_name unless space_name.empty?
          end
        end
        result
      end

      # Clears active flag space selection to default (`fs *`).
      def clear_space : self
        @client.cmd("fs *")
        self
      end

      # Clears all flags in the session (`f-*`).
      def clear_all : self
        @client.cmd("f-*")
        self
      end
    end
  end
end
