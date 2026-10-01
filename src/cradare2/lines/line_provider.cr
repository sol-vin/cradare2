require "./source_location"
require "../models/instruction"

module Cradare2
  module Lines
    # Abstract strategy provider for resolving native instruction addresses to source code locations.
    abstract class LineProvider
      getter name : String

      def initialize(@name : String)
      end

      # Returns true if this provider is available and functional on the host environment.
      abstract def available? : Bool

      # Resolves a single instruction address.
      abstract def resolve_address(address : UInt64) : SourceLocation?

      # Batch-resolves a list of instructions, returning a mapping of Address => SourceLocation.
      abstract def resolve_instructions(
        instructions : Array(Model::Instruction),
        function_name : String? = nil,
      ) : Hash(UInt64, SourceLocation)
    end

    # Provider querying radare2's native code line tables (`CLj`).
    class R2CodelineProvider < LineProvider
      getter client : Client

      def initialize(@client : Client)
        super("radare2_codelines")
      end

      def available? : Bool
        !@client.closed?
      end

      def resolve_address(address : UInt64) : SourceLocation?
        all_lines = query_r2_codelines
        all_lines[address]?
      end

      def resolve_instructions(
        instructions : Array(Model::Instruction),
        function_name : String? = nil,
      ) : Hash(UInt64, SourceLocation)
        result = Hash(UInt64, SourceLocation).new
        return result if instructions.empty?

        r2_lines = query_r2_codelines
        instructions.each do |ins|
          if loc = r2_lines[ins.offset]?
            result[ins.offset] = loc
          end
        end
        result
      end

      def query_r2_codelines : Hash(UInt64, SourceLocation)
        result = Hash(UInt64, SourceLocation).new
        begin
          json_str = @client.cmd("CLj").strip
          return result if json_str.empty? || json_str == "[]"

          parsed = JSON.parse(json_str)
          if arr = parsed.as_a?
            arr.each do |item|
              addr = item["addr"]?.try(&.as_i64?.try(&.to_u64)) || item["offset"]?.try(&.as_i64?.try(&.to_u64))
              file = item["file"]?.try(&.as_s?)
              line = item["line"]?.try(&.as_i?) || 0
              col = item["colu"]?.try(&.as_i?) || item["col"]?.try(&.as_i?) || 0

              if addr && file && line > 0
                result[addr] = SourceLocation.new(file, line, col)
              end
            end
          end
        rescue
        end
        result
      end
    end

    # Provider querying `llvm-symbolizer` via batch standard input pipelines.
    class LlvmSymbolizerProvider < LineProvider
      getter client : Client
      @symbolizer_bin : String?
      @checked_bin : Bool = false

      def initialize(@client : Client)
        super("llvm_symbolizer")
      end

      def available? : Bool
        find_symbolizer != nil
      end

      def resolve_address(address : UInt64) : SourceLocation?
        target_path = resolve_target_binary_path
        return nil unless target_path && File.file?(target_path)
        bin = find_symbolizer
        return nil unless bin

        begin
          process = Process.new(
            command: bin,
            args: ["--obj=#{target_path}", "0x#{address.to_s(16)}"],
            output: Process::Redirect::Pipe,
            error: Process::Redirect::Close
          )
          output = process.output.gets_to_end
          process.wait

          lines = output.lines.map(&.strip).reject(&.empty?)
          if lines.size >= 2
            file_loc = lines[1]
            if file_loc != "??:0:0" && !file_loc.empty?
              if parsed = parse_file_line_col(file_loc)
                file, line, col = parsed
                return SourceLocation.new(file, line, col)
              end
            end
          end
        rescue
        end
        nil
      end

      def resolve_instructions(
        instructions : Array(Model::Instruction),
        function_name : String? = nil,
      ) : Hash(UInt64, SourceLocation)
        result = Hash(UInt64, SourceLocation).new
        return result if instructions.empty?

        target_path = resolve_target_binary_path
        return result unless target_path && File.file?(target_path)
        bin = find_symbolizer
        return result unless bin

        begin
          input_data = instructions.map { |i| "0x#{i.offset.to_s(16)}" }.join("\n") + "\n"
          process = Process.new(
            command: bin,
            args: ["--obj=#{target_path}"],
            input: Process::Redirect::Pipe,
            output: Process::Redirect::Pipe,
            error: Process::Redirect::Close
          )
          process.input.write(input_data.to_slice)
          process.input.close
          output = process.output.gets_to_end
          status = process.wait

          if status.success?
            lines = output.lines.map(&.strip)
            idx = 0
            ins_idx = 0
            while idx < lines.size && ins_idx < instructions.size
              if lines[idx].empty?
                idx += 1
                next
              end
              _fn_line = lines[idx]? || ""
              file_loc = lines[idx + 1]? || ""
              idx += 2
              ins = instructions[ins_idx]
              ins_idx += 1

              if file_loc != "??:0:0" && file_loc != "??:0" && !file_loc.empty?
                if parsed = parse_file_line_col(file_loc)
                  file, line, col = parsed
                  result[ins.offset] = SourceLocation.new(file, line, col)
                end
              end
            end
          end
        rescue
        end
        result
      end

      private def find_symbolizer : String?
        return @symbolizer_bin if @checked_bin
        @checked_bin = true

        if path = Process.find_executable("llvm-symbolizer")
          @symbolizer_bin = path
          return path
        end

        {% if flag?(:windows) %}
          candidates = [
            "C:\\Users\\Ian\\scoop\\apps\\llvm\\current\\bin\\llvm-symbolizer.exe",
            "C:\\Program Files\\LLVM\\bin\\llvm-symbolizer.exe",
            "C:\\Program Files (x86)\\LLVM\\bin\\llvm-symbolizer.exe",
          ]
          candidates.each do |c|
            if File.file?(c)
              @symbolizer_bin = c
              return c
            end
          end
        {% end %}

        nil
      end

      private def resolve_target_binary_path : String?
        info = @client.info
        if core = info.core
          if (file = core.file) && File.file?(file)
            return file
          end
        end
        nil
      end

      private def parse_file_line_col(str : String) : Tuple(String, Int32, Int32)?
        parts = str.split(':')
        if parts.size >= 3
          col = parts.last.to_i?
          line = parts[parts.size - 2].to_i?
          file = parts[0...(parts.size - 2)].join(':')
          if line && col && line > 0
            return {file, line, col}
          end
        elsif parts.size == 2
          file = parts[0]
          line = parts[1].to_i?
          if line && line > 0
            return {file, line, 0}
          end
        end
        nil
      end
    end
  end
end
