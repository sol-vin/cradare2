module Cradare2
  module Lines
    # Represents a source location in a Crystal codebase.
    struct SourceLocation
      getter file : String
      getter line : Int32
      getter column : Int32
      getter source_code : String?

      def initialize(
        @file : String,
        @line : Int32,
        @column : Int32 = 0,
        @source_code : String? = nil,
      )
      end

      # Returns the normalized file path using forward slashes.
      def normalized_file : String
        @file.gsub('\\', '/')
      end

      # Alias for normalized_file
      def normalized_path : String
        normalized_file
      end

      # Returns the base file name (e.g. "main.cr").
      def basename : String
        File.basename(normalized_file)
      end

      # Formats as `file:line` or `file:line:column`.
      def to_s(io : IO) : Nil
        io << @file << ":" << @line
        io << ":" << @column if @column > 0
      end

      # Equality check based on file, line, and column.
      def ==(other : SourceLocation) : Bool
        normalized_file == other.normalized_file &&
          @line == other.line &&
          @column == other.column
      end
    end

    # Represents an assembly machine instruction mapped to its corresponding source location.
    struct InstructionMapping
      getter address : UInt64
      getter size : Int32
      getter opcode : String
      getter bytes : String
      getter location : SourceLocation
      getter function_name : String?

      def initialize(
        @address : UInt64,
        @size : Int32,
        @opcode : String,
        @bytes : String,
        @location : SourceLocation,
        @function_name : String? = nil,
      )
      end

      # Formatted string: `0x140008130: sub rsp, 0x48 -> main.cr:12`
      def to_s(io : IO) : Nil
        io << "0x" << @address.to_s(16) << ": " << @opcode
        io << " -> " << @location
      end
    end

    # Represents a grouping of all assembly instructions that were generated
    # from a single Crystal source code line.
    class LineInstructionGroup
      getter file : String
      getter line : Int32
      property source_code : String?
      getter instructions : Array(InstructionMapping)

      def initialize(
        @file : String,
        @line : Int32,
        @source_code : String? = nil,
        @instructions : Array(InstructionMapping) = [] of InstructionMapping,
      )
      end

      def add_instruction(ins : InstructionMapping) : Nil
        @instructions << ins
      end

      def min_address : UInt64
        return 0_u64 if @instructions.empty?
        @instructions.min_of(&.address)
      end

      def max_address : UInt64
        return 0_u64 if @instructions.empty?
        last = @instructions.max_by(&.address)
        last.address + (last.size > 0 ? last.size.to_u64 : 1_u64)
      end

      def address_range : Range(UInt64, UInt64)
        min_address..max_address
      end

      def total_size : Int32
        @instructions.sum(&.size)
      end

      def count : Int32
        @instructions.size
      end

      def normalized_file : String
        @file.gsub('\\', '/')
      end

      def basename : String
        File.basename(normalized_file)
      end
    end
  end
end
