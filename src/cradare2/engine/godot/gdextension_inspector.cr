require "../../client"
require "../../models/symbol"

module Cradare2
  module Engine
    module Godot
      # Diagnostic result of a GDExtension binary verification.
      struct GDExtensionCheck
        getter valid : Bool
        getter entrypoint_found : Bool
        getter entrypoint_name : String?
        getter exports_count : Int32
        getter arch : String
        getter bits : Int32
        getter warnings : Array(String)

        def initialize(
          @valid : Bool,
          @entrypoint_found : Bool,
          @entrypoint_name : String?,
          @exports_count : Int32,
          @arch : String,
          @bits : Int32,
          @warnings : Array(String) = [] of String,
        )
        end
      end

      # Forensics inspector for GDExtension dynamic shared libraries (Lapis / Godot C++).
      class GDExtensionInspector
        COMMON_ENTRYPOINTS = [
          "lapis_gdextension_entry",
          "godot_gdextension_entry",
          "gdextension_initialize",
          "gdextension_entry",
        ]

        def initialize(@client : Client)
        end

        # Verifies that target binary has valid entrypoint exports for Godot 4.x GDExtension loading.
        def verify_gdextension : GDExtensionCheck
          exports = @client.exports
          info = @client.info
          warnings = [] of String

          entry_name : String? = nil
          found_entry = false

          exports.each do |exp|
            clean_name = exp.name.lstrip('_')
            if COMMON_ENTRYPOINTS.any? { |ep| clean_name.includes?(ep) }
              found_entry = true
              entry_name = exp.name
              break
            end
          end

          if !found_entry
            warnings << "No standard GDExtension entrypoint found (expected one of: #{COMMON_ENTRYPOINTS.join(", ")})"
          end

          if exports.empty?
            warnings << "Binary exports table is empty; Godot will not be able to locate entrypoints"
          end

          valid = found_entry && warnings.empty?

          GDExtensionCheck.new(
            valid: valid,
            entrypoint_found: found_entry,
            entrypoint_name: entry_name,
            exports_count: exports.size,
            arch: info.arch,
            bits: info.bits,
            warnings: warnings
          )
        end

        # Finds imported symbols originating from Godot or GDExtension bindings.
        def find_godot_bindings : Array(Model::Import)
          @client.imports_matching(/godot|gdextension/i)
        end

        # Generates a crash report formatted for Lapis / Godot native crashes.
        def inspect_crash : String
          @client.debug.crash_report
        end
      end
    end
  end
end
