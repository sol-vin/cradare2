require "../cradare2"
require "./platform/ps2/registers"
require "./platform/ps2/gif_dissector"
require "./platform/ps2/vu_profiler"
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

    # Access the PlayStation 2 EE/VU1 memory & cycle profiling bridge (`Cradare2::PS2::VUProfiler`).
    def vu_profiler : PS2::VUProfiler
      ps2.vu_profiler
    end

    # Profiles VU1 Micro-Memory (`0x11008000`) and pipeline stall hazards.
    def profile_vu1(start_pc : UInt32 = 0_u32, max_instructions : Int32 = 256) : PS2::VUProfileReport
      ps2.profile_vu1(start_pc, max_instructions)
    end

    # Declarative block receiver for VU1 profiling over r2pipe.
    def profile_vu1(&block : PS2::VUProfiler ->) : PS2::VUProfileReport
      ps2.profile_vu1(&block)
    end
  end
end
