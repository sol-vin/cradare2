module Cradare2
  module Platform
    module PS2
      module Registers
        # Graphics Synthesizer (GS) Privileged Control Registers (0x12000000 - 0x12001080)
        GS_PMODE    = 0x12000000_u64 # PCRTC Mode setting
        GS_SMODE1   = 0x12000010_u64 # Video sync/clock timings
        GS_SMODE2   = 0x12000020_u64 # Interlace & field/frame mode
        GS_DISPFB1  = 0x12000070_u64 # Read Circuit 1 frame buffer base & width
        GS_DISPLAY1 = 0x12000080_u64 # Read Circuit 1 display position & magnification
        GS_DISPFB2  = 0x12000090_u64 # Read Circuit 2 frame buffer base & width
        GS_DISPLAY2 = 0x120000A0_u64 # Read Circuit 2 display position & magnification
        GS_BGCOLOR  = 0x120000E0_u64 # Background border color
        GS_CSR      = 0x12001000_u64 # GS System status & interrupt reset
        GS_IMR      = 0x12001010_u64 # Interrupt mask register
        GS_BUSDIR   = 0x12001040_u64 # Host interface bus direction

        # Direct Memory Access Controller (DMAC) Registers
        DMAC_CHCR2  = 0x1000A000_u64 # Channel 2 (GIF) Control Register
        DMAC_MADR2  = 0x1000A010_u64 # Channel 2 Memory Address
        DMAC_QWC2   = 0x1000A020_u64 # Channel 2 Quadword Count
        DMAC_TADR2  = 0x1000A030_u64 # Channel 2 Tag Address
        DMAC_D_CTRL = 0x1000E000_u64 # DMAC Global Control
        DMAC_D_STAT = 0x1000E010_u64 # DMAC Status / Interrupt Flags
        DMAC_D_PCR  = 0x1000E020_u64 # DMAC Priority Control

        # PS2 Memory Map Segments
        KUSEG_CACHED   = 0x00000000_u64
        KUSEG_UNCACHED = 0x20000000_u64
        KUSEG_ACCEL    = 0x30000000_u64
        KSEG0          = 0x80000000_u64
        KSEG1          = 0xA0000000_u64

        # Scratchpad RAM (SPRAM) - 16KB fast on-chip CPU memory
        SPRAM_START    = 0x70000000_u64
        SPRAM_END      = 0x70004000_u64
        SPRAM_SIZE     = 0x00004000_u64
        DEFAULT_CANARY = 0xDEADBEEF_u32

        # GS Drawing Register IDs
        REG_PRIM       = 0x00_u64
        REG_RGBAQ      = 0x01_u64
        REG_ST         = 0x02_u64
        REG_UV         = 0x03_u64
        REG_XYZF2      = 0x04_u64
        REG_XYZ2       = 0x05_u64
        REG_TEX0_1     = 0x06_u64
        REG_TEX0_2     = 0x07_u64
        REG_CLAMP_1    = 0x08_u64
        REG_CLAMP_2    = 0x09_u64
        REG_FOG        = 0x0A_u64
        REG_XYZF3      = 0x0C_u64
        REG_XYZ3       = 0x0D_u64
        REG_TEX1_1     = 0x14_u64
        REG_TEX1_2     = 0x15_u64
        REG_TEX2_1     = 0x16_u64
        REG_TEX2_2     = 0x17_u64
        REG_XYOFFSET_1 = 0x18_u64
        REG_XYOFFSET_2 = 0x19_u64
        REG_PRMODECONT = 0x1A_u64
        REG_PRMODE     = 0x1B_u64
        REG_TEXCLUT    = 0x1C_u64
        REG_SCANMSK    = 0x22_u64
        REG_MIPTBP1_1  = 0x34_u64
        REG_MIPTBP1_2  = 0x35_u64
        REG_MIPTBP2_1  = 0x36_u64
        REG_MIPTBP2_2  = 0x37_u64
        REG_TEXA       = 0x3B_u64
        REG_FOGCOL     = 0x3D_u64
        REG_TEXFLUSH   = 0x3F_u64
        REG_SCISSOR_1  = 0x40_u64
        REG_SCISSOR_2  = 0x41_u64
        REG_ALPHA_1    = 0x42_u64
        REG_ALPHA_2    = 0x43_u64
        REG_DIMX       = 0x44_u64
        REG_DTHE       = 0x45_u64
        REG_COLCLAMP   = 0x46_u64
        REG_TEST_1     = 0x47_u64
        REG_TEST_2     = 0x48_u64
        REG_PABE       = 0x49_u64
        REG_FBA_1      = 0x4A_u64
        REG_FBA_2      = 0x4B_u64
        REG_FRAME_1    = 0x4C_u64
        REG_FRAME_2    = 0x4D_u64
        REG_ZBUF_1     = 0x4E_u64
        REG_ZBUF_2     = 0x4F_u64
        REG_BITBLTBUF  = 0x50_u64
        REG_TRXPOS     = 0x51_u64
        REG_TRXREG     = 0x52_u64
        REG_TRXDIR     = 0x53_u64
        REG_HWREG      = 0x54_u64
        REG_SIGNAL     = 0x60_u64
        REG_FINISH     = 0x61_u64
        REG_LABEL      = 0x62_u64

        GS_REG_NAMES = {
          REG_PRIM       => "PRIM",
          REG_RGBAQ      => "RGBAQ",
          REG_ST         => "ST",
          REG_UV         => "UV",
          REG_XYZF2      => "XYZF2",
          REG_XYZ2       => "XYZ2",
          REG_TEX0_1     => "TEX0_1",
          REG_TEX0_2     => "TEX0_2",
          REG_CLAMP_1    => "CLAMP_1",
          REG_CLAMP_2    => "CLAMP_2",
          REG_FOG        => "FOG",
          REG_XYZF3      => "XYZF3",
          REG_XYZ3       => "XYZ3",
          REG_TEX1_1     => "TEX1_1",
          REG_TEX1_2     => "TEX1_2",
          REG_TEX2_1     => "TEX2_1",
          REG_TEX2_2     => "TEX2_2",
          REG_XYOFFSET_1 => "XYOFFSET_1",
          REG_XYOFFSET_2 => "XYOFFSET_2",
          REG_PRMODECONT => "PRMODECONT",
          REG_PRMODE     => "PRMODE",
          REG_TEXCLUT    => "TEXCLUT",
          REG_SCANMSK    => "SCANMSK",
          REG_MIPTBP1_1  => "MIPTBP1_1",
          REG_MIPTBP1_2  => "MIPTBP1_2",
          REG_MIPTBP2_1  => "MIPTBP2_1",
          REG_MIPTBP2_2  => "MIPTBP2_2",
          REG_TEXA       => "TEXA",
          REG_FOGCOL     => "FOGCOL",
          REG_TEXFLUSH   => "TEXFLUSH",
          REG_SCISSOR_1  => "SCISSOR_1",
          REG_SCISSOR_2  => "SCISSOR_2",
          REG_ALPHA_1    => "ALPHA_1",
          REG_ALPHA_2    => "ALPHA_2",
          REG_DIMX       => "DIMX",
          REG_DTHE       => "DTHE",
          REG_COLCLAMP   => "COLCLAMP",
          REG_TEST_1     => "TEST_1",
          REG_TEST_2     => "TEST_2",
          REG_PABE       => "PABE",
          REG_FBA_1      => "FBA_1",
          REG_FBA_2      => "FBA_2",
          REG_FRAME_1    => "FRAME_1",
          REG_FRAME_2    => "FRAME_2",
          REG_ZBUF_1     => "ZBUF_1",
          REG_ZBUF_2     => "ZBUF_2",
          REG_BITBLTBUF  => "BITBLTBUF",
          REG_TRXPOS     => "TRXPOS",
          REG_TRXREG     => "TRXREG",
          REG_TRXDIR     => "TRXDIR",
          REG_HWREG      => "HWREG",
          REG_SIGNAL     => "SIGNAL",
          REG_FINISH     => "FINISH",
          REG_LABEL      => "LABEL",
        }
      end
    end
  end
end
