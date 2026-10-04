require "./gdextension_inspector"
require "../godot"
require "../../address"

module Cradare2
  module Engine
    module Godot
      # High-level helper for Godot 4.x & Lapis GDExtension forensics.
      class Helper
        getter client : Client

        @inspector : GDExtensionInspector?

        def initialize(@client : Client)
        end

        def inspector : GDExtensionInspector
          @inspector ||= GDExtensionInspector.new(@client)
        end

        # Verifies GDExtension binary validity, export tables, and standard entrypoints.
        def verify_gdextension : GDExtensionCheck
          inspector.verify_gdextension
        end

        # Registers Godot print formats (`pf.godot_*`) in the radare2 session.
        def register_formats : self
          Godot.register_formats(@client)
          self
        end

        # Reads and decodes a Godot Object header at target virtual address.
        def read_object(address : Address) : GodotObjectHeader
          Godot.read_object_header(@client, address)
        end

        # Reads and decodes a Godot Variant payload at target virtual address.
        def read_variant(address : Address) : DecodedVariant
          VariantDecoder.decode_at(@client, address)
        end

        # Inspects a Virtual Method Table (vtable) and attempts to resolve symbol names for each entry.
        def inspect_vtable(address : Address, count : Int32 = 8) : Array(Tuple(UInt64, String?))
          pointers = @client.memory.read_pointer_array(address, count)
          result = Array(Tuple(UInt64, String?)).new(count)

          pointers.each do |ptr|
            if ptr > 0_u64
              sym_name = @client.cmd("fd @ 0x#{ptr.to_s(16)}").strip
              sym_name = nil if sym_name.empty? || sym_name.includes?("??")
              result << {ptr, sym_name}
            else
              result << {0_u64, nil}
            end
          end

          result
        end

        # Batch-injects dynamic ClassDB symbols into the specified flag space (default: "godot").
        def inject_classdb_symbols(symbols : Hash(String, Address), space_name : String = "godot") : self
          @client.flags.in_space(space_name) do |f|
            f.batch_set(symbols)
          end
          self
        end

        # Classifies execution crash based on faulting PC register and loaded module boundaries.
        def classify_crash : Tuple(String, String)
          pc = @client.debug.registers.pc
          if mod = @client.debug.module_at(pc)
            name_lower = mod.name.downcase
            category = if name_lower.includes?("godot")
                         "ENGINE"
                       elsif name_lower.includes?("lapis") || name_lower.includes?("gdextension") || name_lower.includes?("bridge")
                         "BRIDGE"
                       else
                         "USER_OR_SYSTEM"
                       end
            {category, mod.name}
          else
            {"UNMAPPED", "Unmapped / Corrupted function pointer (0x#{pc.to_s(16)})"}
          end
        end
      end
    end
  end
end
