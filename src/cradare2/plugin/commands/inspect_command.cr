require "../command"

module Cradare2
  module Plugin
    module Commands
      class InspectCommand < Command
        def initialize
          super("inspect", "Inspect Crystal String, Array, or Slice memory layout", "crystal inspect <string|array|slice> <address>")
        end

        def execute(client : Client, args : Array(String), json : Bool = false) : String
          if args.size < 2
            return json ? {"error" => "Usage: crystal inspect <string|array|slice> <address>"}.to_json : "Usage: crystal inspect <string|array|slice> <address>"
          end

          type = args[0].downcase
          addr = parse_address(args[1])
          unless addr
            return json ? {"error" => "Invalid address: #{args[1]}"}.to_json : "Invalid address: #{args[1]}"
          end

          case type
          when "string", "str"
            s = client.crystal.read_string(addr)
            if json
              return {
                "type"     => "String",
                "address"  => "0x#{addr.to_s(16)}",
                "type_id"  => s.type_id,
                "bytesize" => s.bytesize,
                "length"   => s.length,
                "value"    => s.value,
              }.to_json
            end
            rows = [
              ["type_id:  #{s.type_id}"],
              ["bytesize: #{s.bytesize}"],
              ["length:   #{s.length}"],
              ["value:    \"#{s.value}\""],
            ]
            Util::CLIFormatter.table(["Crystal String @ 0x#{addr.to_s(16)}:"], rows, border_style: :rounded)
          when "array", "arr"
            arr = client.crystal.read_array_header(addr)
            if json
              return {
                "type"           => "Array",
                "address"        => "0x#{addr.to_s(16)}",
                "type_id"        => arr.type_id,
                "size"           => arr.size,
                "capacity"       => arr.capacity,
                "buffer_address" => "0x#{arr.buffer_address.to_s(16)}",
              }.to_json
            end
            rows = [
              ["type_id:  #{arr.type_id}"],
              ["size:     #{arr.size}"],
              ["capacity: #{arr.capacity}"],
              ["buffer:   0x#{arr.buffer_address.to_s(16)}"],
            ]
            Util::CLIFormatter.table(["Crystal Array(T) @ 0x#{addr.to_s(16)}:"], rows, border_style: :rounded)
          when "slice"
            sl = client.crystal.read_slice_header(addr)
            if json
              return {
                "type"            => "Slice",
                "address"         => "0x#{addr.to_s(16)}",
                "size"            => sl.size,
                "read_only"       => sl.read_only,
                "pointer_address" => "0x#{sl.pointer_address.to_s(16)}",
              }.to_json
            end
            rows = [
              ["size:      #{sl.size}"],
              ["read_only: #{sl.read_only}"],
              ["pointer:   0x#{sl.pointer_address.to_s(16)}"],
            ]
            Util::CLIFormatter.table(["Crystal Slice(T) @ 0x#{addr.to_s(16)}:"], rows, border_style: :rounded)
          else
            err = "Unknown inspect type '#{type}'. Supported: string, array, slice."
            json ? {"error" => err}.to_json : err
          end
        end
      end
    end
  end
end
