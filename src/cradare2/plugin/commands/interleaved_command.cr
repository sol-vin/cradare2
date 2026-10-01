require "../command"

module Cradare2
  module Plugin
    module Commands
      class InterleavedCommand < Command
        def initialize
          super("interleaved", "Show interleaved source and assembly view", "crystal interleaved <func|addr>", aliases: ["il"])
        end

        def execute(client : Client, args : Array(String), json : Bool = false) : String
          if args.empty?
            return json ? {"error" => "Usage: crystal interleaved <func_name_or_addr>"}.to_json : "Usage: crystal interleaved <func_name_or_addr>"
          end

          target = args.first
          addr = parse_address(target)

          if json
            grps = addr ? client.crystal.lines.groups(addr) : client.crystal.lines.groups(target)
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
            return {"target" => target, "groups" => groups_json}.to_json
          end

          if addr
            client.crystal.lines.interleaved(addr)
          else
            client.crystal.lines.interleaved(target)
          end
        end
      end
    end
  end
end
