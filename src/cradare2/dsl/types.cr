require "json"
require "../address"
require "../error"

module Cradare2
  class Client
  end

  module DSL
    # DSL for defining, inspecting, and decoding custom binary structures using radare2's `pf` and type engine.
    class Types
      def initialize(@client : Client)
      end

      # Registers a custom print format (`pf.<name> <format> <fields...>`).
      #
      # Format specifiers:
      # - `b` : uint8, byte
      # - `w` : uint16, word
      # - `d` : uint32, dword
      # - `q` : uint64, qword
      # - `f` : float (32-bit)
      # - `F` : double (64-bit)
      # - `p` : pointer (architecture bits)
      # - `z` : null-terminated string
      # - `x` : hex pairs
      def define_format(name : String, format : String, field_names : Array(String) = [] of String) : self
        cmd_str = if field_names.empty?
                    "pf.#{name} #{format}"
                  else
                    "pf.#{name} #{format} #{field_names.join(" ")}"
                  end
        @client.cmd(cmd_str)
        self
      end

      # Convenience helper to define a struct using a mapping of Field Name => Format specifier.
      def define_struct(name : String, fields : Hash(String, String)) : self
        format = fields.values.join
        names = fields.keys
        define_format(name, format, names)
      end

      # Convenience helper to define a struct using an array of tuples ({format, field_name} or {field_name, format}).
      def define_struct(name : String, fields : Array(Tuple(String, String))) : self
        return define_format(name, "", [] of String) if fields.empty?

        # Auto-detect whether first element of tuple is format specifier (short, no underscores) or field name
        first = fields.first
        if first[0].size <= 2 && !first[0].includes?('_')
          format = fields.map(&.[0]).join
          names = fields.map(&.[1])
        else
          format = fields.map(&.[1]).join
          names = fields.map(&.[0])
        end
        define_format(name, format, names)
      end

      # Returns the registered format definition for a named format, or nil if not defined (`pf.<name>`).
      def format(name : String) : String?
        res = @client.cmd("pf.#{name}").strip
        return nil if res.empty? || res.includes?("not found") || res.includes?("Unknown")
        res
      end

      # Decodes and prints formatted struct at `address` into a structured dictionary of Field => JSON::Any (`pfj.<name> @ <addr>`).
      def print_format(name : String, address : Address) : Hash(String, JSON::Any)
        addr_str = AddressUtils.to_hex(address)
        cmd_str = "pfj.#{name} @ #{addr_str}"
        output = @client.cmd(cmd_str).strip

        result = Hash(String, JSON::Any).new
        return result if output.empty?

        begin
          json = JSON.parse(output)
          if arr = json.as_a?
            arr.each do |item|
              if field_name = item["name"]?.try(&.as_s?)
                val = item["value"]? || JSON::Any.new(nil)
                result[field_name] = val
              end
            end
          elsif obj = json.as_h?
            obj.each do |k, v|
              result[k] = v
            end
          end
        rescue ex : JSON::ParseException
          raise TypeDefinitionError.new("Failed to parse pfj response for format '#{name}' at #{addr_str}: #{ex.message}", cause: ex)
        end

        result
      end

      # Loads C header declarations into radare2 (`to <path>`).
      def parse_c_header(header_path : String) : self
        raise TypeDefinitionError.new("Header file not found: #{header_path}") unless File.exists?(header_path)
        @client.cmd("to \"#{header_path}\"")
        self
      end

      # Defines a C typedef, struct, or union in radare2 (`td "<c_code>"`).
      def parse_c_definition(c_code : String) : self
        clean_code = c_code.strip.gsub('"', "\\\"")
        @client.cmd("td \"#{clean_code}\"")
        self
      end

      # Deletes a registered format (`pf.-<name>`).
      def delete_format(name : String) : self
        @client.cmd("pf.-#{name}")
        self
      end
    end
  end
end
