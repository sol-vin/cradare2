require "../models/instruction"

module Cradare2
  class Client
  end

  module DSL
    # DSL for disassembling code and decompilation.
    class Disassembly
      def initialize(@client : Client)
      end

      private def addr_s(address : UInt64 | Int32 | Int64 | String) : String
        case address
        when Int
          "0x#{address.to_s(16)}"
        else
          address.to_s
        end
      end

      # Disassembles instructions at current seek or specified address as text.
      def text(count : Int32 = 10, at : (UInt64 | Int32 | Int64 | String)? = nil) : String
        cmd_str = at ? "pd #{count} @ #{addr_s(at)}" : "pd #{count}"
        @client.cmd(cmd_str)
      end

      # Disassembles instructions at current seek or specified address returning typed instructions.
      def instructions(count : Int32 = 10, at : (UInt64 | Int32 | Int64 | String)? = nil) : Array(Model::Instruction)
        cmd_str = at ? "pdj #{count} @ #{addr_s(at)}" : "pdj #{count}"
        begin
          @client.cmdj(cmd_str, as: Array(Model::Instruction))
        rescue
          [] of Model::Instruction
        end
      end

      # Disassembles instructions starting at specified address.
      def at(address : UInt64 | Int32 | Int64 | String, count : Int32 = 1) : Array(Model::Instruction)
        instructions(count: count, at: address)
      end

      # Disassembles an entire function by name or address as formatted text.
      def function_text(target : (UInt64 | Int32 | Int64 | String)? = nil) : String
        cmd_str = target ? "pdf @ #{addr_s(target)}" : "pdf"
        @client.cmd(cmd_str)
      end

      # Disassembles an entire function returning typed instructions.
      def function_instructions(target : (UInt64 | Int32 | Int64 | String)? = nil) : Array(Model::Instruction)
        cmd_str = target ? "pdfj @ #{addr_s(target)}" : "pdfj"
        results = [] of Model::Instruction
        begin
          json = @client.cmdj(cmd_str)
          if ops = json["ops"]?
            if arr = ops.as_a?
              arr.each do |op|
                begin
                  results << Model::Instruction.from_json(op.to_json)
                rescue
                end
              end
            end
          end
        rescue
        end
        results
      end

      # Decompiles current function or target to C-like pseudocode (pdc, or pdg if ghidra is available).
      # Optionally auto-analyzes function first (`af @ <addr>`) and falls back to disassembly (`pdf`) if decompilation fails.
      def decompile(
        target : (UInt64 | Int32 | Int64 | String)? = nil,
        auto_analyze : Bool = true,
        fallback_asm : Bool = true,
      ) : String
        if auto_analyze && target
          @client.cmd("af @ #{addr_s(target)}") rescue nil
        end

        ghidra_cmd = target ? "pdg @ #{addr_s(target)}" : "pdg"
        ghidra_output = @client.cmd(ghidra_cmd).strip
        if !ghidra_output.empty? && !ghidra_output.includes?("Cannot") && !ghidra_output.includes?("not found")
          return ghidra_output
        end

        pdc_cmd = target ? "pdc @ #{addr_s(target)}" : "pdc"
        pdc_output = @client.cmd(pdc_cmd).strip
        if !pdc_output.empty? && !pdc_output.includes?("Cannot find function")
          return pdc_output
        end

        if fallback_asm
          function_text(target).strip
        else
          pdc_output
        end
      end

      # Decompiles function with side-by-side assembly instruction comparison (pdca).
      def side_by_side(target : (UInt64 | Int32 | Int64 | String)? = nil, auto_analyze : Bool = true) : String
        if auto_analyze && target
          @client.cmd("af @ #{addr_s(target)}") rescue nil
        end
        cmd_str = target ? "pdca @ #{addr_s(target)}" : "pdca"
        res = @client.cmd(cmd_str).strip
        res.empty? || res.includes?("Cannot") ? decompile(target, auto_analyze: false) : res
      end

      # Disassembles instructions interleaved with high-level source lines (pdls).
      def source_interleaved(target : (UInt64 | Int32 | Int64 | String)? = nil, count : Int32 = 20) : String
        cmd_str = target ? "pdls #{count} @ #{addr_s(target)}" : "pdls #{count}"
        @client.cmd(cmd_str).strip
      end

      # DWARF / PDB line-annotated decompilation if line metadata is present (CLd).
      def annotated_source(target : (UInt64 | Int32 | Int64 | String)? = nil) : String
        cmd_str = target ? "CLd @ #{addr_s(target)}" : "CLd"
        res = @client.cmd(cmd_str).strip
        res.empty? || res.includes?("Cannot") ? decompile(target) : res
      end
    end
  end
end
