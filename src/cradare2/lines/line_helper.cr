require "./source_map"
require "./line_resolver"
require "./source_reader"

module Cradare2
  module Lines
    # High-level DSL helper providing convenient access to source-line-to-assembly matching.
    # Accessible via `client.crystal.lines` or block forms.
    class LineHelper
      getter client : Client
      @map : SourceMap?
      @resolver : LineResolver?
      @reader : SourceReader?

      def initialize(@client : Client)
      end

      # Returns the source reader instance.
      def reader : SourceReader
        @reader ||= SourceReader.new
      end

      # Returns the source map instance, lazily resolving lines from the binary if not yet loaded.
      def map : SourceMap
        @map ||= begin
          m = SourceMap.new(reader)
          r = LineResolver.new(@client, m)
          @resolver = r
          m
        end
      end

      # Returns the line resolver instance.
      def resolver : LineResolver
        @resolver ||= LineResolver.new(@client, map)
      end

      # Resolves line information for all analyzed functions in the binary.
      def resolve_all : SourceMap
        resolver.resolve_all_functions
        map
      end

      # Resolves line information for a specific function by name or address.
      def resolve_function(target : String | UInt64) : SourceMap
        if target.is_a?(UInt64)
          if fn = @client.functions.find { |f| f.offset == target }
            resolver.resolve_function(fn)
          else
            resolver.resolve_function(target, "sub_#{target.to_s(16)}")
          end
        else
          if fn = @client.functions.find { |f| f.name == target || f.name.includes?(target) }
            resolver.resolve_function(fn)
          elsif sym = @client.symbols.find { |s| s.name == target || s.name.includes?(target) }
            resolver.resolve_function(sym.vaddr, sym.name, sym.size || 64_u64)
          end
        end
        map
      end

      # Resolves and returns the source location for an instruction address.
      def at(address : UInt64) : SourceLocation?
        if existing = map.find_by_address(address)
          return existing
        end

        resolver.resolve_address(address)
      end

      # Returns all instructions that were compiled from the given source file and line.
      def for_line(file : String, line : Int32) : Array(InstructionMapping)
        # If map is empty, trigger initial resolution
        if map.empty?
          resolve_all
        end

        map.find_by_line(file, line)
      end

      # Returns line instruction groups for a given function name or address.
      def groups(target : String | UInt64) : Array(LineInstructionGroup)
        resolve_function(target)

        if target.is_a?(UInt64)
          fn = @client.functions.find { |f| f.offset == target }
          if fn
            return map.groups_for_range(fn.offset, fn.offset + fn.size.to_u64)
          end

          if ins = map.find_instruction_containing(target)
            if fn_name = ins.function_name
              return map.groups_for_function_name(fn_name)
            else
              return map.groups_for_range(ins.address, ins.address + (ins.size > 0 ? ins.size.to_u64 : 1_u64))
            end
          end
        else
          return map.groups_for_function_name(target)
        end

        [] of LineInstructionGroup
      end

      # Returns a formatted interleaved view showing source code lines alongside
      # their generated assembly instructions.
      def interleaved(target : String | UInt64) : String
        grp_list = groups(target)
        map.format_interleaved_view(grp_list)
      end

      # Synchronizes all discovered source line mappings into radare2 (`CL` and `CC`).
      def sync_to_r2(annotate_comments : Bool = true) : Int32
        if map.empty?
          resolve_all
        end

        map.sync_to_r2(@client, annotate_comments: annotate_comments)
      end

      # Clears cached mappings and re-resolves from the target.
      def reload : SourceMap
        @map = nil
        @resolver = nil
        resolve_all
      end
    end
  end
end
