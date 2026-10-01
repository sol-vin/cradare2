require "../command"

module Cradare2
  module Plugin
    module Commands
      class CrashCommand < Command
        def initialize
          super("crash", "Generate full demangled crash/debug report", "crystal crash")
        end

        def execute(client : Client, args : Array(String), json : Bool = false) : String
          if json
            diag = client.debug.diagnose_crash
            return {
              "reason"               => diag.reason,
              "probable_cause"       => diag.probable_cause.to_s,
              "faulting_address"     => "0x#{diag.faulting_address.to_s(16)}",
              "faulting_symbol"      => diag.faulting_symbol,
              "faulting_instruction" => diag.faulting_instruction.try(&.opcode),
              "recommendations"      => diag.recommendations,
              "backtrace_frames"     => diag.backtrace.map { |f| {"frame" => f.frame, "pc" => "0x#{f.pc.to_s(16)}", "func" => f.function} },
            }.to_json
          end

          Util::CLIFormatter.markdown(client.crystal.crash_report)
        end
      end
    end
  end
end
