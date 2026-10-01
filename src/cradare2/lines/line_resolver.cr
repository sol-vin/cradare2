require "./source_map"
require "../models/instruction"
require "../models/function"

module Cradare2
  module Lines
    # Resolves source lines from binaries using radare2 DWARF tables or external LLVM symbolizer.
    class LineResolver
      getter client : Client
      getter map : SourceMap

      def initialize(@client : Client, @map : SourceMap = SourceMap.new)
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

      # Resolves a list of instructions and adds them to the source map.
      def resolve_instructions(
        instructions : Array(Model::Instruction),
        function_name : String? = nil,
      ) : SourceMap
        return @map if instructions.empty?

        # First, try radare2's native line info: query CLj
        r2_lines = query_r2_codelines

        unresolved = [] of Model::Instruction

        instructions.each do |ins|
          if loc = r2_lines[ins.offset]?
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

        # If some instructions were not resolved by r2 CLj, try llvm-symbolizer
        if !unresolved.empty?
          resolve_with_llvm_symbolizer(unresolved, function_name)
        end

        @map
      end

      # Resolves a single address.
      def resolve_address(address : UInt64) : SourceLocation?
        if existing = @map.find_by_address(address)
          return existing
        end

        # Try r2 CLj
        r2_lines = query_r2_codelines
        if loc = r2_lines[address]?
          @map.add(address, loc.file, loc.line, loc.column)
          return @map.find_by_address(address)
        end

        # Try llvm-symbolizer
        target_path = resolve_target_binary_path
        if target_path && File.file?(target_path)
          if loc = query_llvm_symbolizer_single(target_path, address)
            @map.add(address, loc.file, loc.line, loc.column)
            return @map.find_by_address(address)
          end
        end

        nil
      end

      # Queries radare2's `CLj` command to extract all loaded code-line entries.
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

      # Convenience helper returning array of all resolved source locations from r2 codelines.
      def resolve_from_r2_codelines : Array(SourceLocation)
        query_r2_codelines.values
      end

      # Uses `llvm-symbolizer` to resolve addresses if it is installed on the host.
      def resolve_with_llvm_symbolizer(
        instructions : Array(Model::Instruction),
        function_name : String? = nil,
      ) : Nil
        binary_path = resolve_target_binary_path
        return unless binary_path && File.file?(binary_path)

        symbolizer_cmd = find_llvm_symbolizer
        return unless symbolizer_cmd

        # Batch query addresses via stdin
        begin
          input_data = instructions.map { |i| "0x#{i.offset.to_s(16)}" }.join("\n") + "\n"

          process = Process.new(
            command: symbolizer_cmd,
            args: ["--obj=#{binary_path}"],
            input: Process::Redirect::Pipe,
            output: Process::Redirect::Pipe,
            error: Process::Redirect::Close
          )

          process.input.write(input_data.to_slice)
          process.input.close

          output = process.output.gets_to_end
          status = process.wait

          if status.success?
            parse_symbolizer_output(output, instructions, function_name)
          end
        rescue
        end
      end

      private def parse_symbolizer_output(
        output : String,
        instructions : Array(Model::Instruction),
        function_name : String?,
      ) : Nil
        # llvm-symbolizer outputs two lines per address:
        # Line 1: Function name
        # Line 2: File:line:column
        # Blank line separator
        lines = output.lines.map(&.strip)
        idx = 0
        ins_idx = 0

        while idx < lines.size && ins_idx < instructions.size
          # Skip empty lines
          if lines[idx].empty?
            idx += 1
            next
          end

          fn_line = lines[idx]? || ""
          file_loc_line = lines[idx + 1]? || ""
          idx += 2

          ins = instructions[ins_idx]
          ins_idx += 1

          # Check if valid file:line:col
          if file_loc_line != "??:0:0" && file_loc_line != "??:0" && !file_loc_line.empty?
            parsed = parse_file_line_col(file_loc_line)
            if parsed
              file, line, col = parsed
              resolved_fn = fn_line.empty? || fn_line.starts_with?("??") ? function_name : fn_line
              @map.add(
                address: ins.offset,
                file: file,
                line: line,
                column: col,
                opcode: ins.opcode,
                size: ins.size,
                bytes: ins.bytes,
                function_name: resolved_fn
              )
            end
          end
        end
      end

      private def parse_file_line_col(location_str : String) : Tuple(String, Int32, Int32)?
        # Handle Windows paths like C:\dir\file.cr:12:3 or /path/file.cr:12:3
        # Split from right to left for col and line
        parts = location_str.split(':')
        if parts.size >= 3
          # Format: file:line:col (e.g. C:\foo\bar.cr:10:5 -> parts = ["C", "\foo\bar.cr", "10", "5"])
          col_str = parts.last
          line_str = parts[parts.size - 2]
          file_str = parts[0...(parts.size - 2)].join(':')

          line = line_str.to_i?
          col = col_str.to_i?

          if line && col && line > 0
            return {file_str, line, col}
          end
        elsif parts.size == 2
          file_str = parts[0]
          line = parts[1].to_i?
          if line && line > 0
            return {file_str, line, 0}
          end
        end

        nil
      end

      private def query_llvm_symbolizer_single(binary_path : String, address : UInt64) : SourceLocation?
        symbolizer_cmd = find_llvm_symbolizer
        return nil unless symbolizer_cmd

        begin
          process = Process.new(
            command: symbolizer_cmd,
            args: ["--obj=#{binary_path}", "0x#{address.to_s(16)}"],
            output: Process::Redirect::Pipe,
            error: Process::Redirect::Close
          )
          output = process.output.gets_to_end
          process.wait

          lines = output.lines.map(&.strip).reject(&.empty?)
          if lines.size >= 2
            file_loc_line = lines[1]
            if file_loc_line != "??:0:0" && !file_loc_line.empty?
              if parsed = parse_file_line_col(file_loc_line)
                file, line, col = parsed
                return SourceLocation.new(file, line, col)
              end
            end
          end
        rescue
        end

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

        # Fallback query `i~file[1]` or `i~core.file`
        begin
          res = @client.cmd("ij")
          json = JSON.parse(res)
          if path = json["core"]?.try(&.["file"]?.try(&.as_s?))
            return path if File.file?(path)
          end
        rescue
        end

        nil
      end

      # Locates the `llvm-symbolizer` binary on the host system.
      def find_llvm_symbolizer : String?
        # Check standard PATH
        if path = Process.find_executable("llvm-symbolizer")
          return path
        end

        # Check common Windows scoop / LLVM directories
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
    end
  end
end
