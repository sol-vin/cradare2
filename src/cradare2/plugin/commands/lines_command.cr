require "../command"

module Cradare2
  module Plugin
    module Commands
      class LinesCommand < Command
        def initialize
          super("lines", "Show source-line-to-asm mappings or sync with radare2", "crystal lines [addr|func|sync]")
        end

        def execute(client : Client, args : Array(String), json : Bool = false) : String
          if args.first? == "sync"
            count = client.crystal.lines.sync_to_r2(annotate_comments: true)
            if json
              return {"synchronized" => count}.to_json
            end
            return "Synchronized #{count} source line mappings into radare2 (CL table and CC comments)."
          end

          if args.empty?
            map = client.crystal.lines.map
            if map.empty?
              client.crystal.lines.resolve_all
            end
            files = map.files

            if json
              files_summary = files.map do |f|
                lines = map.lines_for_file(f)
                {"file" => f, "mapped_lines" => lines.size, "lines" => lines}
              end
              return {"files_count" => files.size, "files" => files_summary}.to_json
            end

            if files.empty?
              return "No source line mappings found. Ensure binary has debug info (PDB or DWARF)."
            end

            String.build do |str|
              str.puts "Mapped Source Files (#{files.size}):"
              files.each do |f|
                lines = map.lines_for_file(f)
                str.puts "  - #{f} (#{lines.size} mapped lines)"
              end
              str.puts "\nUse 'crystal lines <addr|func>' or 'crystal interleaved <func>' to inspect."
            end
          else
            target = args.first
            addr = parse_address(target)
            if addr
              loc = client.crystal.lines.at(addr)
              if loc
                if json
                  return {
                    "address"     => "0x#{addr.to_s(16)}",
                    "file"        => loc.file,
                    "line"        => loc.line,
                    "column"      => loc.column,
                    "source_code" => loc.source_code,
                  }.to_json
                end
                src = loc.source_code || "(source line unavailable)"
                "0x#{addr.to_s(16)} -> #{loc}\n  | #{src.strip}"
              else
                if json
                  return {"error" => "No source mapping found for address 0x#{addr.to_s(16)}"}.to_json
                end
                "No source mapping found for address 0x#{addr.to_s(16)}."
              end
            else
              # Treat as function name
              if json
                grps = client.crystal.lines.groups(target)
                groups_json = grps.map do |g|
                  {
                    "file"         => g.file,
                    "line"         => g.line,
                    "source_code"  => g.source_code,
                    "min_address"  => "0x#{g.min_address.to_s(16)}",
                    "max_address"  => "0x#{g.max_address.to_s(16)}",
                    "instructions" => g.instructions.map do |ins|
                      {
                        "address" => "0x#{ins.address.to_s(16)}",
                        "size"    => ins.size,
                        "opcode"  => ins.opcode,
                        "bytes"   => ins.bytes,
                      }
                    end,
                  }
                end
                return {"function" => target, "groups" => groups_json}.to_json
              end
              client.crystal.lines.interleaved(target)
            end
          end
        end
      end
    end
  end
end
