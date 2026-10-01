require "./source_map"
require "./line_provider"
require "../models/instruction"
require "../models/function"

module Cradare2
  module Lines
    # Resolves source lines from binaries using a chain of pluggable LineProviders.
    class LineResolver
      getter client : Client
      getter map : SourceMap
      getter providers : Array(LineProvider) = [] of LineProvider

      def initialize(
        @client : Client,
        @map : SourceMap = SourceMap.new,
        providers : Array(LineProvider)? = nil,
      )
        @providers = providers || [
          R2CodelineProvider.new(@client),
          LlvmSymbolizerProvider.new(@client),
        ] of LineProvider
      end

      # Registers an additional line provider into the resolution chain.
      def register_provider(provider : LineProvider) : self
        @providers << provider
        self
      end

      # Populates the source map for all analyzed functions in the binary.
      def resolve_all_functions : SourceMap
        functions = @client.functions
        if functions.empty?
          @client.analyze.calls
          functions = @client.functions
        end

        functions.each do |fn|
          resolve_function(fn)
        end
        @map
      end

      # Populates the source map for a function given its offset, name, and estimated size.
      def resolve_function(offset : UInt64, name : String? = nil, size : UInt64 = 64_u64) : SourceMap
        instructions = @client.disasm.function_instructions(offset)
        if instructions.empty?
          count = size > 0 ? (size / 4).clamp(10, 200).to_i32 : 30
          instructions = @client.disasm.instructions(count, at: offset)
        end
        resolve_instructions(instructions, name)
        @map
      end

      # Populates the source map for a single function model.
      def resolve_function(fn : Model::Function) : SourceMap
        resolve_function(fn.offset, fn.name, fn.size)
      end

      # Resolves a list of instructions through the provider chain and adds them to the source map.
      def resolve_instructions(
        instructions : Array(Model::Instruction),
        function_name : String? = nil,
      ) : SourceMap
        return @map if instructions.empty?

        remaining = instructions.dup

        @providers.each do |provider|
          break if remaining.empty?
          next unless provider.available?

          resolved = provider.resolve_instructions(remaining, function_name)
          unresolved = [] of Model::Instruction

          remaining.each do |ins|
            if loc = resolved[ins.offset]?
              @map.add(
                address: ins.offset,
                file: loc.file,
                line: loc.line,
                column: loc.column,
                opcode: ins.opcode,
                size: ins.size,
                bytes: ins.bytes,
                function_name: function_name
              )
            else
              unresolved << ins
            end
          end

          remaining = unresolved
        end

        @map
      end

      # Resolves a single address through the provider chain.
      def resolve_address(address : UInt64) : SourceLocation?
        if existing = @map.find_by_address(address)
          return existing
        end

        @providers.each do |provider|
          next unless provider.available?
          if loc = provider.resolve_address(address)
            @map.add(address, loc.file, loc.line, loc.column)
            return @map.find_by_address(address)
          end
        end

        nil
      end

      # Queries radare2's `CLj` command to extract all loaded code-line entries.
      def query_r2_codelines : Hash(UInt64, SourceLocation)
        r2_provider = @providers.find(&.is_a?(R2CodelineProvider)).as?(R2CodelineProvider)
        if r2_provider
          r2_provider.query_r2_codelines
        else
          R2CodelineProvider.new(@client).query_r2_codelines
        end
      end

      # Convenience helper returning array of all resolved source locations from r2 codelines.
      def resolve_from_r2_codelines : Array(SourceLocation)
        query_r2_codelines.values
      end

      # Locates the `llvm-symbolizer` binary on the host system.
      def find_llvm_symbolizer : String?
        if path = Process.find_executable("llvm-symbolizer")
          return path
        end

        {% if flag?(:windows) %}
          candidates = [
            "C:\\Users\\Ian\\scoop\\apps\\llvm\\current\\bin\\llvm-symbolizer.exe",
            "C:\\Program Files\\LLVM\\bin\\llvm-symbolizer.exe",
            "C:\\Program Files (x86)\\LLVM\\bin\\llvm-symbolizer.exe",
          ]
          candidates.each do |c|
            return c if File.file?(c)
          end
        {% end %}

        nil
      end

      # Returns the path of the opened binary by querying radare2 info.
      def resolve_target_binary_path : String?
        info = @client.info
        if core = info.core
          if (file = core.file) && File.file?(file)
            return file
          end
        end
        nil
      end
    end
  end
end
