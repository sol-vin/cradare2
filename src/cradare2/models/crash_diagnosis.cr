require "./instruction"
require "./stack_frame"
require "../analysis/memory_classifier"

module Cradare2
  module Model
    # Structured crash diagnosis report containing architectural classification,
    # register forensics, root-cause pattern analysis, and actionable remediation advice.
    struct CrashDiagnosis
      getter reason : String
      getter probable_cause : Symbol
      getter faulting_address : UInt64
      getter faulting_instruction : Instruction?
      getter faulting_symbol : String?
      getter registers : Analysis::RegisterAnalysis
      getter backtrace : Array(StackFrame)
      getter recommendations : Array(String)

      def initialize(
        @reason : String,
        @probable_cause : Symbol,
        @faulting_address : UInt64,
        @faulting_instruction : Instruction?,
        @faulting_symbol : String?,
        @registers : Analysis::RegisterAnalysis,
        @backtrace : Array(StackFrame) = [] of StackFrame,
        @recommendations : Array(String) = [] of String,
      )
      end

      # Formatted string report
      def to_s(io : IO) : Nil
        io.puts "=== Native Crash Diagnostic Report ==="
        io.puts "Probable Cause:      #{@probable_cause.to_s.upcase}"
        io.puts "Faulting Address:    0x#{@faulting_address.to_s(16)}"
        if sym = @faulting_symbol
          io.puts "Faulting Symbol:     #{sym}"
        end
        if instr = @faulting_instruction
          io.puts "Faulting Opcode:     #{instr.opcode} (#{instr.disasm || ""})"
        end
        io.puts

        io.puts "Registers (Forensics):"
        io.puts "  PC: #{@registers.pc}"
        io.puts "  SP: #{@registers.sp}"
        io.puts "  BP: #{@registers.bp}"

        @registers.registers.each do |r_name, classified|
          next if ["pc", "sp", "bp", "rip", "rsp", "rbp", "eip", "esp", "ebp"].includes?(r_name)
          io.puts "  #{r_name.upcase.rjust(3)}: #{classified}"
        end
        io.puts

        unless @recommendations.empty?
          io.puts "Diagnostic Recommendations:"
          @recommendations.each do |rec|
            io.puts "  - #{rec}"
          end
          io.puts
        end

        unless @backtrace.empty?
          io.puts "Call Stack:"
          @backtrace.each_with_index do |frame, idx|
            io.puts "  ##{idx} 0x#{frame.pc.to_s(16)} in #{frame.function}"
          end
        end
      end
    end
  end
end
