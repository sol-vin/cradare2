require "../command"
require "../../util/demangler"

module Cradare2
  module Plugin
    module Commands
      class MethodsCommand < Command
        def initialize
          super("methods", "List all methods for a given class", "crystal methods <class>")
        end

        def execute(client : Client, args : Array(String), json : Bool = false) : String
          if args.empty?
            return json ? {"error" => "Usage: crystal methods <class_name>"}.to_json : "Usage: crystal methods <class_name>"
          end

          cls = args.first
          methods = client.crystal.methods_for_class(cls)

          if methods.empty?
            syms = client.crystal.symbols_for_class(cls)
            if syms.empty?
              return json ? {"class" => cls, "methods" => [] of String}.to_json : "No methods found for class '#{cls}'."
            end

            if json
              sym_items = syms.map do |s|
                demangled = Util::Demangler.demangle(s.name, client.transport)
                {
                  "address"  => "0x#{s.vaddr.to_s(16)}",
                  "name"     => demangled,
                  "raw_name" => s.name,
                  "size"     => s.size,
                }
              end
              return {"class" => cls, "methods" => sym_items}.to_json
            end

            rows = syms.map do |s|
              demangled = Util::Demangler.demangle(s.name, client.transport)
              ["0x#{s.vaddr.to_s(16)}", demangled, "#{s.size} bytes"]
            end
            tbl = Util::CLIFormatter.table(["Address", "Method Signature", "Size"], rows, border_style: :rounded)

            return String.build do |str|
              str.puts Util::CLIFormatter.rule("Methods for #{cls} (#{syms.size}):")
              str.puts
              str.puts tbl
            end
          end

          if json
            method_items = methods.map do |m|
              demangled = Util::Demangler.demangle(m.name, client.transport)
              {
                "address"  => "0x#{m.offset.to_s(16)}",
                "name"     => demangled,
                "raw_name" => m.name,
                "size"     => m.size,
              }
            end
            return {"class" => cls, "methods" => method_items}.to_json
          end

          rows = methods.map do |m|
            demangled = Util::Demangler.demangle(m.name, client.transport)
            ["0x#{m.offset.to_s(16)}", demangled, "#{m.size} bytes"]
          end
          tbl = Util::CLIFormatter.table(["Address", "Method Signature", "Size"], rows, border_style: :rounded)

          String.build do |str|
            str.puts Util::CLIFormatter.rule("Methods for #{cls} (#{methods.size}):")
            str.puts
            str.puts tbl
          end
        end
      end
    end
  end
end
