require "../command"

module Cradare2
  module Plugin
    module Commands
      class DetectCommand < Command
        def initialize
          super("detect", "Check if target is a Crystal binary", "crystal detect")
        end

        def execute(client : Client, args : Array(String), json : Bool = false) : String
          is_cr = client.crystal.crystal_binary?
          ep = client.crystal.entrypoint

          if json
            return {
              "crystal"    => is_cr,
              "entrypoint" => ep,
            }.to_json
          end

          if is_cr
            ep_str = ep ? "0x#{ep.to_s(16)}" : "unknown"
            "Target is a Crystal binary! (Entrypoint: #{ep_str})"
          else
            "Target does NOT appear to be a Crystal binary."
          end
        end
      end
    end
  end
end
