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
      def decompile(target : (UInt64 | String)? = nil) : String
        ghidra_cmd = target ? "pdg @ #{target}" : "pdg"
        ghidra_output = @client.cmd(ghidra_cmd)
        if !ghidra_output.empty? && !ghidra_output.includes?("Cannot") && !ghidra_output.includes?("not found")
          return ghidra_output
        end

        pdc_cmd = target ? "pdc @ #{target}" : "pdc"
        @client.cmd(pdc_cmd)
      end
    end
  end
end
