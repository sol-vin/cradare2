require "./registers"
require "./gif_dissector"
require "../../util/script_builder"
require "../../address"

module Cradare2
  module Platform
    module PS2
      # High-level helper providing PlayStation 2 Emotion Engine, GS, SPRAM, and GIF packet forensics.
      class Helper
        getter client : Client

        def initialize(@client : Client)
        end

        # Configures radare2 disassembler for PS2 Emotion Engine (MIPS R5900, 32-bit).
        def configure_ee : self
          @client.cmd("e asm.arch = mips; e asm.cpu = r5900; e asm.bits = 32")
          self
        end

        # Configures radare2 disassembler for PS2 Input/Output Processor (MIPS I R3000A, 32-bit).
        def configure_iop : self
          @client.cmd("e asm.arch = mips; e asm.cpu = mips1; e asm.bits = 32")
          self
        end

        # Injects PS2 EE memory map flags (SPRAM, GS registers, DMAC) into the "ps2" flag space.
        def setup_memory_map : self
          flags = {
            "spram.start"        => Registers::SPRAM_START,
            "spram.canary"       => Registers::SPRAM_START,
            "spram.frame_count"  => Registers::SPRAM_START + 0x04_u64,
            "spram.vm_status"    => Registers::SPRAM_START + 0x08_u64,
            "spram.end"          => Registers::SPRAM_END,
            "gs.pmode"           => Registers::GS_PMODE,
            "gs.smode1"          => Registers::GS_SMODE1,
            "gs.smode2"          => Registers::GS_SMODE2,
            "gs.dispfb1"         => Registers::GS_DISPFB1,
            "gs.display1"        => Registers::GS_DISPLAY1,
            "gs.dispfb2"         => Registers::GS_DISPFB2,
            "gs.display2"        => Registers::GS_DISPLAY2,
            "gs.bgcolor"         => Registers::GS_BGCOLOR,
            "gs.csr"             => Registers::GS_CSR,
            "gs.imr"             => Registers::GS_IMR,
            "gs.busdir"          => Registers::GS_BUSDIR,
            "dmac.chcr2"         => Registers::DMAC_CHCR2,
            "dmac.madr2"         => Registers::DMAC_MADR2,
            "dmac.qwc2"          => Registers::DMAC_QWC2,
            "dmac.tadr2"         => Registers::DMAC_TADR2,
            "dmac.d_ctrl"        => Registers::DMAC_D_CTRL,
            "dmac.d_stat"        => Registers::DMAC_D_STAT,
            "dmac.d_pcr"         => Registers::DMAC_D_PCR,
            "mem.kuseg_cached"   => Registers::KUSEG_CACHED,
            "mem.kuseg_uncached" => Registers::KUSEG_UNCACHED,
            "mem.kuseg_accel"    => Registers::KUSEG_ACCEL,
            "mem.kseg0"          => Registers::KSEG0,
            "mem.kseg1"          => Registers::KSEG1,
          }

          @client.flags.in_space("ps2") do |f|
            f.batch_set(flags)
          end
          self
        end

        # Registers standard PS2 GS and Citrine print formats (`pf.gs_*`, `pf.giftag`, `pf.citrine_obj`).
        def register_formats : self
          @client.types.define_format("gs_pmode", "ww (qword)raw (dword)low (dword)high")
          @client.types.define_format("gs_dispfb", "ww (qword)raw (dword)fbp_fbw_psm (dword)dbx_dby")
          @client.types.define_format("gs_display", "ww (qword)raw (dword)dx_dy_mag (dword)dw_dh")
          @client.types.define_format("giftag", "qq (qword)low_nloop_eop_flg (qword)high_regs")
          @client.types.define_format("citrine_obj", "ii (dword)class_id (dword)field_count")
          self
        end

        # Verifies the SPRAM stack canary value (default 0xDEADBEEF).
        def verify_canary(address : Address = Registers::SPRAM_START, expected : UInt32 = Registers::DEFAULT_CANARY) : Bool
          val = @client.memory.read_u32(address)
          val == expected
        end

        # Reads raw bytes from SPRAM at given offset (0 to 16KB).
        def read_spram(offset : Int32 = 0, size : Int32 = 64) : Bytes
          addr = Registers::SPRAM_START + offset.to_u64
          @client.memory.read_bytes(addr, size)
        end

        # Decodes a 128-bit GIFTag header from memory at given address.
        def decode_giftag(address : Address) : GifDissector::GifTagInfo
          bytes = @client.memory.read_bytes(address, 16)
          GifDissector.decode_giftag(bytes)
        end

        # Dissects a series of 128-bit GIF packet items starting at given address.
        def dissect_gif_packet(address : Address, max_items : Int32 = 50) : Array(GifDissector::GifItemInfo)
          tag = decode_giftag(address)
          total_items = [tag.nloop.to_i, max_items].min
          bytes_needed = 16 + (total_items * 16)
          raw = @client.memory.read_bytes(address, bytes_needed)
          GifDissector.dissect_packet(raw, max_items)
        end

        # Generates a standalone radare2 .rc script for PS2 / Citrine reverse engineering.
        def generate_script(target_path : String = "") : String
          builder = Util::ScriptBuilder.new("PlayStation 2 / Citrine radare2 debug script")
          builder.target(target_path) unless target_path.empty?
          builder.arch("mips")
          builder.cpu("r5900")
          builder.bits(32)

          builder.section("EE Memory Map")
          builder.flag("mem.kuseg_cached", Registers::KUSEG_CACHED)
          builder.flag("mem.kuseg_uncached", Registers::KUSEG_UNCACHED)
          builder.flag("mem.kseg0", Registers::KSEG0)
          builder.flag("mem.kseg1", Registers::KSEG1)
          builder.flag("spram.start", Registers::SPRAM_START)
          builder.flag("spram.canary", Registers::SPRAM_START)
          builder.flag("spram.end", Registers::SPRAM_END)

          builder.section("GS Privileged Registers")
          builder.flag("gs.pmode", Registers::GS_PMODE)
          builder.flag("gs.csr", Registers::GS_CSR)

          builder.section("DMAC Registers")
          builder.flag("dmac.chcr2", Registers::DMAC_CHCR2)
          builder.flag("dmac.madr2", Registers::DMAC_MADR2)

          builder.section("Print Formats")
          builder.format("gs_pmode", "ww (qword)raw (dword)low (dword)high")
          builder.format("giftag", "qq (qword)low_nloop_eop_flg (qword)high_regs")
          builder.format("citrine_obj", "ii (dword)class_id (dword)field_count")

          builder.section("Macros")
          builder.macro("ps2_spram", "pxw 32 @ 0x70000000")
          builder.macro("ps2_canary_check", "pxw 4 @ 0x70000000")

          builder.to_s
        end
      end
    end
  end
end
