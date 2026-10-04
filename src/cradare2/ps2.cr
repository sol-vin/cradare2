require "../cradare2"
require "./platform/ps2/registers"
require "./platform/ps2/gif_dissector"
require "./platform/ps2/helper"

module Cradare2
  class Client
    # Access the PlayStation 2 Emotion Engine and Citrine platform helper.
    def ps2 : Platform::PS2::Helper
      @ps2 ||= Platform::PS2::Helper.new(self)
    end

    def ps2(&block : Platform::PS2::Helper ->) : self
      block.call(ps2)
      self
    end

    # Citrine alias for `ps2`
    def citrine : Platform::PS2::Helper
      ps2
    end

    def citrine(&block : Platform::PS2::Helper ->) : self
      block.call(citrine)
      self
    end
  end
end
