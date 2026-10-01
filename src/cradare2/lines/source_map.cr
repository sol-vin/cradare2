require "./source_location"
require "./source_reader"
require "base64"

module Cradare2
  module Lines
    # Bidirectional mapping engine between native assembly instructions and Crystal source code.
    class SourceMap
      getter address_to_instruction : Hash(UInt64, InstructionMapping) = Hash(UInt64, InstructionMapping).new
      # Normalized file => (Line => Array(InstructionMapping))
      getter file_to_lines : Hash(String, Hash(Int32, Array(InstructionMapping))) = Hash(String, Hash(Int32, Array(InstructionMapping))).new
      getter reader : SourceReader
      @registered_files : Set(String) = Set(String).new

      def initialize(@reader : SourceReader = SourceReader.new)
      end

      # Adds a mapping between an instruction address and a source location.
      def add(
        address : UInt64,
        file : String,
        line : Int32,
        column : Int32 = 0,
        opcode : String = "",
        size : Int32 = 0,
        bytes : String? = "",
        function_name : String? = nil,
        source_text : String? = nil,
      ) : InstructionMapping
        # If source_text is not provided, query reader
        resolved_text = source_text || @reader.read_line(file, line)
        location = SourceLocation.new(file, line, column, resolved_text)
        mapping = InstructionMapping.new(address, size, opcode, bytes || "", location, function_name)

        @address_to_instruction[address] = mapping

        norm_file = normalize_file(file)
        lines_hash = @file_to_lines[norm_file] ||= Hash(Int32, Array(InstructionMapping)).new
        ins_list = lines_hash[line] ||= Array(InstructionMapping).new
        ins_list << mapping

        # Also register by basename for flexible lookup
        base_file = File.basename(norm_file)
        if base_file != norm_file
          base_hash = @file_to_lines[base_file] ||= Hash(Int32, Array(InstructionMapping)).new
          base_list = base_hash[line] ||= Array(InstructionMapping).new
          base_list << mapping unless base_list.any? { |m| m.address == address }
        end

        @registered_files << file
        mapping
      end

      # Clears all mappings.
      def clear : Nil
        @address_to_instruction.clear
        @file_to_lines.clear
        @registered_files.clear
      end

      # Returns the number of mapped instructions.
      def size : Int32
        @address_to_instruction.size
      end

      # Returns true if no mappings exist.
      def empty? : Bool
        @address_to_instruction.empty?
      end

      # Finds the source location for an instruction address.
      def find_by_address(address : UInt64) : SourceLocation?
        find_instruction(address).try(&.location)
      end

      # Finds the mapped instruction for an exact address.
      def find_instruction(address : UInt64) : InstructionMapping?
        @address_to_instruction[address]?
      end

      # Finds the instruction matching or containing the given address (within instruction size range).
      def find_instruction_containing(address : UInt64) : InstructionMapping?
        if exact = @address_to_instruction[address]?
          return exact
        end

        # Check if address falls within [ins.address, ins.address + ins.size)
        @address_to_instruction.each_value do |ins|
          if ins.size > 0 && address >= ins.address && address < (ins.address + ins.size)
            return ins
          end
        end

        nil
      end

      # Finds all instructions generated for a given file and line number.
      def find_by_line(file : String, line : Int32) : Array(InstructionMapping)
        norm = normalize_file(file)
        if lines_hash = @file_to_lines[norm]?
          if list = lines_hash[line]?
            return list.sort_by(&.address)
          end
        end

        base = File.basename(norm)
        if lines_hash = @file_to_lines[base]?
          if list = lines_hash[line]?
            return list.sort_by(&.address)
          end
        end

        [] of InstructionMapping
      end

      # Finds all line-to-instruction mappings for a given file.
      def find_by_file(file : String) : Hash(Int32, Array(InstructionMapping))
        norm = normalize_file(file)
        if lines_hash = @file_to_lines[norm]?
          return lines_hash
        end

        base = File.basename(norm)
        if lines_hash = @file_to_lines[base]?
          return lines_hash
        end

        Hash(Int32, Array(InstructionMapping)).new
      end

      # Returns all unique source file paths recorded in the map.
      def files : Array(String)
        @registered_files.to_a.sort
      end

      # Returns all unique line numbers mapped for a given file.
      def lines_for_file(file : String) : Array(Int32)
        find_by_file(file).keys.sort
      end

      # Groups instructions within an address range or function into LineInstructionGroups.
      def groups_for_range(start_addr : UInt64, end_addr : UInt64) : Array(LineInstructionGroup)
        matching_ins = @address_to_instruction.values.select do |ins|
          ins.address >= start_addr && ins.address < end_addr
        end.sort_by(&.address)

        build_groups(matching_ins)
      end

      # Groups instructions for a specific function name.
      def groups_for_function_name(fn_name : String) : Array(LineInstructionGroup)
        matching_ins = @address_to_instruction.values.select do |ins|
          ins.function_name == fn_name || ins.function_name.try(&.includes?(fn_name))
        end.sort_by(&.address)

        build_groups(matching_ins)
      end

      # Generates a formatted interleaved view displaying Crystal source code lines
      # alongside the disassembled instructions that implement each line.
      def format_interleaved_view(
        groups : Array(LineInstructionGroup),
        show_context : Bool = false,
        context_window : Int32 = 1,
      ) : String
        return "No source line mappings found." if groups.empty?

        String.build do |str|
          current_file = ""

          groups.each do |group|
            if group.file != current_file
              current_file = group.file
              str.puts
              str.puts "=== File: #{current_file} ==="
            end

            str.puts
            # Print source line
            src_text = group.source_code || @reader.read_line(group.file, group.line) || "(source unavailable)"
            str.puts "Line #{group.line.to_s.rjust(4)}: | #{src_text.rstrip}"
            str.puts "             | [0x#{group.min_address.to_s(16)} - 0x#{group.max_address.to_s(16)}, #{group.count} insts, #{group.total_size} bytes]"

            # Print assembly instructions for this source line
            group.instructions.each do |ins|
              bytes_str = ins.bytes.empty? ? "" : ins.bytes.ljust(16)
              str.puts "  0x#{ins.address.to_s(16).rjust(8, '0')}  #{bytes_str}  #{ins.opcode}"
            end
          end
        end
      end

      # Synchronizes all mappings into a running radare2 session.
      # Registers entries into radare2's `CL` codeline table and optionally sets `CC` comments.
      def sync_to_r2(client : Client, annotate_comments : Bool = true) : Int32
        return 0 if @address_to_instruction.empty?

        count = 0
        @address_to_instruction.each do |addr, ins|
          loc = ins.location

          # To prevent radare2 on Windows from splitting "C:\foo.cr:12" on the drive colon,
          # we pass a relative path or forward-slash normalized path without colon.
          safe_file = safe_r2_path(loc.file)

          # Register in r2 codeline table: `CL addr file:line`
          client.cmd("CL 0x#{addr.to_s(16)} #{safe_file}:#{loc.line}")
          count += 1

          # Optionally add source code comment above instruction
          if annotate_comments
            if text = loc.source_code || @reader.read_line(loc.file, loc.line)
              clean_comment = text.strip.gsub('"', "'").gsub(';', ',')
              unless clean_comment.empty?
                # Add comment with file:line and source text
                comment = "#{loc.basename}:#{loc.line} | #{clean_comment}"
                client.cmd("CC \"#{comment}\" @ 0x#{addr.to_s(16)}")
              end
            end
          end
        end

        # Enable dwarf line display in disassembly listings
        client.cmd("e asm.dwarf=true")
        count
      end

      private def build_groups(instructions : Array(InstructionMapping)) : Array(LineInstructionGroup)
        groups = [] of LineInstructionGroup
        return groups if instructions.empty?

        # Group consecutive instructions belonging to the same (file, line)
        current_group : LineInstructionGroup? = nil

        instructions.each do |ins|
          loc = ins.location
          if current_group && current_group.file == loc.file && current_group.line == loc.line
            current_group.add_instruction(ins)
          else
            new_group = LineInstructionGroup.new(
              file: loc.file,
              line: loc.line,
              source_code: loc.source_code || @reader.read_line(loc.file, loc.line)
            )
            new_group.add_instruction(ins)
            groups << new_group
            current_group = new_group
          end
        end

        groups
      end

      # Sanitizes a path for radare2's `CL` command to avoid Windows drive-letter colon confusion.
      private def safe_r2_path(path : String) : String
        # If relative, use forward slashes
        norm = path.gsub('\\', '/')

        # If it's a Windows absolute path like C:/Users/..., convert to relative or basename
        if norm.size >= 2 && norm[1] == ':'
          # Try making relative to current directory
          rel = Path[norm].relative_to(Path[Dir.current]).to_s.gsub('\\', '/') rescue nil
          if rel && !rel.starts_with?("..")
            return rel
          end

          # If cannot make relative, use forward slashes starting with /c/...
          drive = norm[0].downcase
          rest = norm[2..]
          return "/#{drive}#{rest}"
        end

        norm
      end

      private def normalize_file(file : String) : String
        file.gsub('\\', '/').downcase
      end
    end
  end
end
