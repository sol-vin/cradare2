require "../command"

module Cradare2
  module Plugin
    module Commands
      class AsmCommand < Command
        def initialize
          super("asm", "Show machine instructions for a source line", "crystal asm <file:line>")
        end

        def execute(client : Client, args : Array(String), json : Bool = false) : String
          if args.empty?
            return json ? {"error" => "Usage: crystal asm <file:line>"}.to_json : "Usage: crystal asm <file:line>"
          end

          spec = args.first
          parts = spec.split(':')
          if parts.size < 2
            return json ? {"error" => "Invalid format. Expected <file:line> (e.g. main.cr:12)"}.to_json : "Invalid format. Expected <file:line> (e.g. main.cr:12)"
          end

          line = parts.last.to_i?
          file = parts[0...(parts.size - 1)].join(':')
          unless line
            return json ? {"error" => "Invalid line number: #{parts.last}"}.to_json : "Invalid line number: #{parts.last}"
          end

          instructions = client.crystal.lines.for_line(file, line)
          if instructions.empty?
            return json ? {"error" => "No instructions found for #{file}:#{line}."}.to_json : "No instructions found for #{file}:#{line}."
          end

          if json
            return {
              "file"         => file,
              "line"         => line,
              "count"        => instructions.size,
              "instructions" => instructions.map do |ins|
                {
                  "address" => "0x#{ins.address.to_s(16)}",
                  "size"    => ins.size,
                  "opcode"  => ins.opcode,
                  "bytes"   => ins.bytes,
                }
              end,
            }.to_json
          end

          rows = instructions.map do |ins|
            bytes_str = ins.bytes.empty? ? "-" : ins.bytes
            ["0x#{ins.address.to_s(16).rjust(8, '0')}", bytes_str, ins.opcode]
          end
          tbl = Util::CLIFormatter.table(["Address", "Bytes", "Disassembly"], rows, border_style: :rounded)

          String.build do |str|
            str.puts Util::CLIFormatter.rule("Instructions for #{file}:#{line} (#{instructions.size} insts):")
            str.puts
            str.puts tbl
          end
        end
      end
    end
  end
end
