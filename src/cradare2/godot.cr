require "../cradare2"
require "./engine/godot"
require "./engine/godot/gdextension_inspector"
require "./engine/godot/helper"

module Cradare2
  class Client
    # Access the Godot Engine and Lapis GDExtension helper.
    def godot : Engine::Godot::Helper
      @godot ||= Engine::Godot::Helper.new(self)
    end

    def godot(&block : Engine::Godot::Helper ->) : self
      block.call(godot)
      self
    end

    # Lapis alias for `godot`
    def lapis : Engine::Godot::Helper
      godot
    end

    def lapis(&block : Engine::Godot::Helper ->) : self
      block.call(lapis)
      self
    end

    # Reads and decodes a Godot 4 Object header at the given virtual address.
    def godot_object(address : Address) : Engine::Godot::GodotObjectHeader
      Engine::Godot.read_object_header(self, address)
    end

    # Reads and decodes a Godot 4 Variant payload at the given virtual address.
    def godot_variant(address : Address) : Engine::Godot::DecodedVariant
      Engine::Godot::VariantDecoder.decode_at(self, address)
    end
  end
end
