require "json"
require "./registers"
require "./gif_dissector"
require "../../client"
require "../../gdb/client"

module Cradare2
  module Platform
    module PS2
      # =========================================================================
      # Tier 1: Core Engine Models & Data Structures
      # =========================================================================

      # Classification of PS2 VU1 pipeline stall and register hazards.
      enum HazardType
        FmacRaw          # 4-cycle FMAC Read-After-Write stall on VF01..VF31 or ACC
        LoadUse          # 4-cycle LQ/LQI/LQD memory load to Upper/Lower VF read stall
        FmacStore        # 4-cycle Upper FMAC VF write to Lower SQ/SQI/SQD store stall
        FdivWait         # 7-cycle (DIV/SQRT) or 13-cycle (RSQRT) Q-register wait/read stall
        EfuWait          # Elementary Function Unit (P-register) wait stall
        IaluBranch       # 1-cycle VI write before conditional branch (IBEQ/IBNE/etc.) hazard
        IlwLoadRaw       # 4-cycle ILW integer load to VI read stall
        BranchDelaySlot  # Branch placed inside the delay slot of a preceding branch or [E]-bit
        SameCycleVfWrite # Both Upper and Lower write overlapping fields of the same VF register
        LoiLowerConflict # Upper sets I-bit (LOI) while Lower contains an active instruction
        XgkickStall      # Back-to-back XGKICK instructions stalling on GIF Path 1
      end

      # Severity level of a detected VU1 pipeline hazard.
      enum HazardSeverity
        Warning # Hardware interlocks and stalls pipeline for N cycles
        Error   # Hardware race condition, undefined behavior, or missing synchronization
      end

      # Decoded 64-bit Dual-Issue PlayStation 2 VU1 Microinstruction (`0x11008000 + pc * 8`).
      struct VUInstruction
        include JSON::Serializable

        property pc : UInt32
        property address : UInt64
        property raw : UInt64
        property upper_word : UInt32
        property lower_word : UInt32
        property upper_op : String
        property lower_op : String
        property upper_mnemonic : String
        property lower_mnemonic : String
        property dest_mask : UInt8
        property lower_dest_mask : UInt8
        property upper_fd : UInt8
        property upper_fs : UInt8
        property upper_ft : UInt8
        property lower_ft : UInt8
        property lower_fs : UInt8
        property lower_id : UInt8
        property lower_is : UInt8
        property lower_it : UInt8
        property lower_imm : Int32
        property writes_acc : Bool
        property reads_acc : Bool
        property reads_q : Bool
        property reads_p : Bool
        property reads_i : Bool
        property fdiv_latency : Int32
        property i_bit : Bool
        property e_bit : Bool
        property m_bit : Bool
        property d_bit : Bool
        property t_bit : Bool

        def initialize(
          @pc : UInt32,
          @address : UInt64,
          @raw : UInt64,
          @upper_word : UInt32,
          @lower_word : UInt32,
          @upper_op : String = "NOP",
          @lower_op : String = "NOP",
          @upper_mnemonic : String = "NOP",
          @lower_mnemonic : String = "NOP",
          @dest_mask : UInt8 = 0_u8,
          @lower_dest_mask : UInt8 = 0_u8,
          @upper_fd : UInt8 = 0_u8,
          @upper_fs : UInt8 = 0_u8,
          @upper_ft : UInt8 = 0_u8,
          @lower_ft : UInt8 = 0_u8,
          @lower_fs : UInt8 = 0_u8,
          @lower_id : UInt8 = 0_u8,
          @lower_is : UInt8 = 0_u8,
          @lower_it : UInt8 = 0_u8,
          @lower_imm : Int32 = 0,
          @writes_acc : Bool = false,
          @reads_acc : Bool = false,
          @reads_q : Bool = false,
          @reads_p : Bool = false,
          @reads_i : Bool = false,
          @fdiv_latency : Int32 = 0,
          @i_bit : Bool = false,
          @e_bit : Bool = false,
          @m_bit : Bool = false,
          @d_bit : Bool = false,
          @t_bit : Bool = false,
        )
        end

        def upper_nop? : Bool
          @upper_op == "NOP"
        end

        def lower_nop? : Bool
          @lower_op == "NOP" || @lower_op == "LOI"
        end

        # Returns true if both Upper (FMAC) and Lower execution units execute active operations simultaneously.
        def dual_issued? : Bool
          !upper_nop? && !lower_nop?
        end

        # Returns the 32-bit IEEE 754 float immediate when the Upper `I` bit (LOI) is set.
        def immediate_float : Float32?
          return nil unless @i_bit
          @lower_word.unsafe_as(Float32)
        end

        # Returns true if Upper writes to a general-purpose VF register (`vf01..vf31`).
        def upper_writes_vf? : Bool
          return false if upper_nop? || @writes_acc || @upper_op == "CLIP" || @dest_mask == 0_u8 || @upper_fd == 0_u8
          true
        end

        # Returns true if Upper reads `vf[upper_fs]`.
        def upper_reads_fs? : Bool
          !upper_nop? && @upper_fs != 0_u8
        end

        # Returns true if Upper reads `vf[upper_ft]`.
        def upper_reads_ft? : Bool
          return false if upper_nop? || @upper_ft == 0_u8
          case @upper_op
          when "ADDI", "ADDQ", "SUBI", "SUBQ", "MADDI", "MADDQ", "MSUBI", "MSUBQ",
               "MAXI", "MINII", "MULI", "MULQ", "ADDAI", "ADDAQ", "SUBAI", "SUBAQ",
               "MADDAI", "MADDAQ", "MSUBAI", "MSUBAQ", "MULAI", "MULAQ",
               "ABS", "FTOI0", "FTOI4", "FTOI12", "FTOI15", "ITOF0", "ITOF4", "ITOF12", "ITOF15"
            false
          else
            true
          end
        end

        # Returns true if Lower writes a VF register (`LQ`, `LQI`, `LQD`, `MOVE`, `MR32`, `MFIR`).
        def lower_writes_vf? : Bool
          return false if @lower_dest_mask == 0_u8 || @lower_ft == 0_u8
          case @lower_op
          when "LQ", "LQI", "LQD", "MOVE", "MR32", "MFIR"
            true
          else
            false
          end
        end

        # Returns true if Lower is a memory load into a VF register (`LQ`, `LQI`, `LQD`).
        def lower_loads_vf? : Bool
          return false if @lower_dest_mask == 0_u8 || @lower_ft == 0_u8
          case @lower_op
          when "LQ", "LQI", "LQD"
            true
          else
            false
          end
        end

        # Returns true if Lower reads `vf[lower_fs]` (`SQ`, `SQI`, `SQD`, `MOVE`, `MR32`, `MTIR`, `DIV`, `RSQRT`).
        def lower_reads_vf_fs? : Bool
          return false if @lower_fs == 0_u8
          case @lower_op
          when "SQ", "SQI", "SQD", "MOVE", "MR32", "MTIR", "DIV", "RSQRT"
            true
          else
            false
          end
        end

        # Returns true if Lower reads `vf[lower_ft]` (`DIV`, `SQRT`, `RSQRT`).
        def lower_reads_vf_ft? : Bool
          return false if @lower_ft == 0_u8
          case @lower_op
          when "DIV", "SQRT", "RSQRT"
            true
          else
            false
          end
        end

        # Returns the destination VI register (`1..15`) written by Lower, or `0_u8` if none.
        def lower_vi_dest : UInt8
          case @lower_op
          when "IADD", "ISUB", "IAND", "IOR"
            @lower_id
          when "IADDI", "IADDIU", "ISUBIU", "ILW", "MTIR", "BAL", "JALR", "XTOP", "XITOP"
            @lower_it
          else
            0_u8
          end
        end

        def branch? : Bool
          case @lower_op
          when "B", "BAL", "JR", "JALR", "IBEQ", "IBNE", "IBLTZ", "IBGTZ", "IBLEZ", "IBGEZ"
            true
          else
            false
          end
        end

        def waitq? : Bool
          @lower_op == "WAITQ"
        end

        def waitp? : Bool
          @lower_op == "WAITP"
        end

        def xgkick? : Bool
          @lower_op == "XGKICK"
        end

        def disasm : String
          "#{@upper_mnemonic} | #{@lower_mnemonic}"
        end
      end

      # Represents a detected pipeline stall or register hazard in VU1 microcode.
      struct VUStallHazard
        include JSON::Serializable

        property pc : UInt32
        property address : UInt64
        property producer_pc : UInt32
        property hazard_type : HazardType
        property severity : HazardSeverity
        property register : String
        property stall_cycles : Int32
        property description : String

        def initialize(
          @pc : UInt32,
          @address : UInt64,
          @producer_pc : UInt32,
          @hazard_type : HazardType,
          @severity : HazardSeverity,
          @register : String,
          @stall_cycles : Int32,
          @description : String,
        )
        end

        def error? : Bool
          @severity.error?
        end

        def warning? : Bool
          @severity.warning?
        end
      end

      # Represents a 128-bit Quadword (`x, y, z, w` floats and `ix, iy, iz, iw` ints) in VU1 Data Memory (`0x1100C000`).
      struct VUQuadword
        include JSON::Serializable

        property qw_index : UInt32
        property address : UInt64
        property x : Float32
        property y : Float32
        property z : Float32
        property w : Float32
        property ix : UInt32
        property iy : UInt32
        property iz : UInt32
        property iw : UInt32

        def initialize(
          @qw_index : UInt32,
          @address : UInt64,
          @x : Float32,
          @y : Float32,
          @z : Float32,
          @w : Float32,
          @ix : UInt32,
          @iy : UInt32,
          @iz : UInt32,
          @iw : UInt32,
        )
        end

        def zero? : Bool
          @ix == 0_u32 && @iy == 0_u32 && @iz == 0_u32 && @iw == 0_u32
        end

        def to_f32_tuple : Tuple(Float32, Float32, Float32, Float32)
          {@x, @y, @z, @w}
        end

        def to_u32_tuple : Tuple(UInt32, UInt32, UInt32, UInt32)
          {@ix, @iy, @iz, @iw}
        end

        def to_bytes : Bytes
          bytes = Bytes.new(16)
          IO::ByteFormat::LittleEndian.encode(@ix, bytes[0, 4])
          IO::ByteFormat::LittleEndian.encode(@iy, bytes[4, 4])
          IO::ByteFormat::LittleEndian.encode(@iz, bytes[8, 4])
          IO::ByteFormat::LittleEndian.encode(@iw, bytes[12, 4])
          bytes
        end
      end

      # Snapshot of VU1 Data Memory (`0x1100C000`), VIF1 double-buffer pointers, and EE hardware timers.
      struct VUMemorySnapshot
        include JSON::Serializable

        property base_address : UInt64
        property quadwords : Array(VUQuadword)
        property vif1_stat : UInt32
        property vif1_top : UInt32
        property vif1_tops : UInt32
        property vif1_itop : UInt32
        property ee_timer0 : UInt32
        property ee_timer1 : UInt32

        def initialize(
          @base_address : UInt64,
          @quadwords : Array(VUQuadword),
          @vif1_stat : UInt32 = 0_u32,
          @vif1_top : UInt32 = 0_u32,
          @vif1_tops : UInt32 = 0_u32,
          @vif1_itop : UInt32 = 0_u32,
          @ee_timer0 : UInt32 = 0_u32,
          @ee_timer1 : UInt32 = 0_u32,
        )
        end

        def non_zero_quadwords : Array(VUQuadword)
          @quadwords.reject(&.zero?)
        end

        def quadword_at(index : Int) : VUQuadword?
          @quadwords.find { |q| q.qw_index == index.to_u32 }
        end

        # Dissects an embedded GS GIF packet stored in this VU1 Data Memory snapshot starting at `qw_offset`.
        def dissect_gif_packet_at(qw_offset : Int32 = 0, max_items : Int32 = 32) : Array(GifDissector::GifItemInfo)
          start_idx = @quadwords.index { |q| q.qw_index == qw_offset.to_u32 }
          return [] of GifDissector::GifItemInfo unless start_idx

          remaining = @quadwords.size - start_idx
          return [] of GifDissector::GifItemInfo if remaining <= 0

          buf = Bytes.new(remaining * 16)
          (0...remaining).each do |i|
            qw_bytes = @quadwords[start_idx + i].to_bytes
            buf[i * 16, 16].copy_from(qw_bytes)
          end
          GifDissector.dissect_packet(buf, max_items)
        end
      end

      # Comprehensive VU1 Microprogram Cycle, Stall, and Frame-Budget Profile Report.
      struct VUProfileReport
        include JSON::Serializable

        property start_address : UInt64
        property instruction_count : Int32
        property active_op_count : Int32
        property dual_issue_count : Int32
        property base_cycles : Int32
        property stall_cycles : Int32
        property total_cycles : Int32
        property ee_equivalent_cycles : Int32
        property ipc : Float64
        property dual_issue_ratio : Float64
        property ntsc_frame_budget_pct : Float64
        property pal_frame_budget_pct : Float64
        property terminated_by_e_bit : Bool
        property xgkick_count : Int32
        property instructions : Array(VUInstruction)
        property hazards : Array(VUStallHazard)

        def initialize(
          @start_address : UInt64,
          @instruction_count : Int32,
          @active_op_count : Int32,
          @dual_issue_count : Int32,
          @base_cycles : Int32,
          @stall_cycles : Int32,
          @total_cycles : Int32,
          @ee_equivalent_cycles : Int32,
          @ipc : Float64,
          @dual_issue_ratio : Float64,
          @ntsc_frame_budget_pct : Float64,
          @pal_frame_budget_pct : Float64,
          @terminated_by_e_bit : Bool,
          @xgkick_count : Int32,
          @instructions : Array(VUInstruction),
          @hazards : Array(VUStallHazard),
        )
        end

        def clean? : Bool
          @hazards.empty?
        end

        def has_errors? : Bool
          @hazards.any?(&.error?)
        end

        def errors : Array(VUStallHazard)
          @hazards.select(&.error?)
        end

        def warnings : Array(VUStallHazard)
          @hazards.select(&.warning?)
        end

        def summary : String
          String.build do |io|
            io << "VU1 Profile @ 0x#{@start_address.to_s(16).upcase}: "
            io << "#{@instruction_count} insts (#{@dual_issue_count} dual-issued, #{(@dual_issue_ratio * 100.0).round(1)}%), "
            io << "base=#{@base_cycles} cyc, stalls=#{@stall_cycles} cyc, total=#{@total_cycles} VU1 cyc "
            io << "(#{@ee_equivalent_cycles} EE cyc, NTSC=#{@ntsc_frame_budget_pct.round(4)}%, IPC=#{@ipc.round(2)}, "
            io << "hazards=#{@hazards.size}, xgkicks=#{@xgkick_count})"
          end
        end
      end

      # =========================================================================
      # Tier 1: Core VU1 Memory & Cycle Profiling Bridge (`Cradare2::PS2::VUProfiler`)
      # =========================================================================

      # PS2 EE/VU1 memory & cycle profiling bridge inspecting VU1 Micro-Memory (`0x11008000`),
      # VU1 Data Memory (`0x1100C000`), and pipeline stall hazards over r2pipe, GDB RSP, or byte slices.
      class VUProfiler
        FMAC_LATENCY        =              4
        LOAD_LATENCY        =              4
        ILW_LATENCY         =              4
        FDIV_DIV_LATENCY    =              7
        FDIV_RSQRT_LATENCY  =             13
        UPPER_NOP_CANONICAL = 0x000002FF_u32
        LOWER_NOP_CANONICAL = 0x8000033C_u32

        getter client : Client?
        getter gdb : Gdb::Client?
        property micro_buffer : Bytes
        property data_buffer : Bytes
        property micro_base : UInt64
        property data_base : UInt64
        property start_pc : UInt32
        property max_instructions : Int32
        property stop_on_e_bit : Bool
        property xgkick_min_separation : Int32
        property data_qw_offset : Int32
        property data_qw_count : Int32

        def initialize(@client : Client)
          @gdb = nil
          @micro_buffer = Bytes.empty
          @data_buffer = Bytes.empty
          @micro_base = Registers::VU1_MICRO_MEM
          @data_base = Registers::VU1_DATA_MEM
          @start_pc = 0_u32
          @max_instructions = 256
          @stop_on_e_bit = true
          @xgkick_min_separation = 4
          @data_qw_offset = 0
          @data_qw_count = 64
        end

        def initialize(@gdb : Gdb::Client)
          @client = nil
          @micro_buffer = Bytes.empty
          @data_buffer = Bytes.empty
          @micro_base = Registers::VU1_MICRO_MEM
          @data_base = Registers::VU1_DATA_MEM
          @start_pc = 0_u32
          @max_instructions = 256
          @stop_on_e_bit = true
          @xgkick_min_separation = 4
          @data_qw_offset = 0
          @data_qw_count = 64
        end

        def initialize(@micro_buffer : Bytes = Bytes.empty, @data_buffer : Bytes = Bytes.empty)
          @client = nil
          @gdb = nil
          @micro_base = Registers::VU1_MICRO_MEM
          @data_base = Registers::VU1_DATA_MEM
          @start_pc = 0_u32
          @max_instructions = 256
          @stop_on_e_bit = true
          @xgkick_min_separation = 4
          @data_qw_offset = 0
          @data_qw_count = 64
        end

        def self.from_gdb(gdb : Gdb::Client) : self
          new(gdb)
        end

        def self.from_bytes(micro_bytes : Bytes, data_bytes : Bytes = Bytes.empty) : self
          new(micro_bytes, data_bytes)
        end

        # Unified memory reader across r2pipe (`Client`), GDB RSP (`Gdb::Client`), or local buffers.
        def read_bytes(address : UInt64, length : Int32) : Bytes
          return Bytes.empty if length <= 0

          if c = @client
            bytes = c.memory.read_bytes(address, length)
            return bytes unless bytes.empty?
          end

          if g = @gdb
            if bytes = g.read_memory(address, length)
              return bytes
            end
          end

          # Fallback to in-memory buffers if address falls within VU1 Micro or Data memory ranges
          if address >= @micro_base && address < @micro_base + Registers::VU1_MICRO_MEM_SIZE && !@micro_buffer.empty?
            offset = (address - @micro_base).to_i32
            if offset >= 0 && offset < @micro_buffer.size
              avail = Math.min(length, @micro_buffer.size - offset)
              return @micro_buffer[offset, avail]
            end
          elsif address >= @data_base && address < @data_base + Registers::VU1_DATA_MEM_SIZE && !@data_buffer.empty?
            offset = (address - @data_base).to_i32
            if offset >= 0 && offset < @data_buffer.size
              avail = Math.min(length, @data_buffer.size - offset)
              return @data_buffer[offset, avail]
            end
          end

          Bytes.empty
        end

        # Reads a 32-bit unsigned integer in PlayStation 2 little-endian byte order.
        def read_u32(address : UInt64) : UInt32
          if c = @client
            return c.memory.read_u32(address)
          elsif g = @gdb
            return g.read_u32(address) || 0_u32
          else
            bytes = read_bytes(address, 4)
            return 0_u32 if bytes.size < 4
            IO::ByteFormat::LittleEndian.decode(UInt32, bytes)
          end
        end

        # Reads raw bytes from VU1 Micro-Memory (`0x11008000 + offset_bytes`).
        def read_micro_memory(offset_bytes : Int32 = 0, size : Int32 = 2048) : Bytes
          read_bytes(@micro_base + offset_bytes.to_u64, size)
        end

        # Reads raw bytes from VU1 Data Memory (`0x1100C000 + offset_bytes`).
        def read_data_memory(offset_bytes : Int32 = 0, size : Int32 = 1024) : Bytes
          read_bytes(@data_base + offset_bytes.to_u64, size)
        end

        # Measures elapsed Emotion Engine Hardware Timer 0 (`0x10000000`) bus cycles around a block.
        def measure_ee_cycles(&block : ->) : UInt32
          start_t0 = read_u32(Registers::EE_T0_COUNT)
          yield
          end_t0 = read_u32(Registers::EE_T0_COUNT)
          end_t0 &- start_t0
        end

        # Formats a 4-bit destination mask (`0b1000`=x, `0b0100`=y, `0b0010`=z, `0b0001`=w) into a suffix string.
        def self.format_dest_mask(mask : UInt8) : String
          m = mask & 0xF_u8
          return "none" if m == 0_u8
          String.build(4) do |io|
            io << 'x' if (m & 0x8_u8) != 0
            io << 'y' if (m & 0x4_u8) != 0
            io << 'z' if (m & 0x2_u8) != 0
            io << 'w' if (m & 0x1_u8) != 0
          end
        end

        def self.format_broadcast(bc : UInt8) : String
          case bc & 0x3_u8
          when 0_u8 then "x"
          when 1_u8 then "y"
          when 2_u8 then "z"
          else           "w"
          end
        end

        def self.format_vf(idx : UInt8) : String
          idx < 10 ? "vf0#{idx}" : "vf#{idx}"
        end

        def self.format_vi(idx : UInt8) : String
          idx < 10 ? "vi0#{idx}" : "vi#{idx}"
        end

        # Decodes a single 64-bit Dual-Issue VU1 Microinstruction (`lower_word` in bits 0..31, `upper_word` in bits 32..63).
        def self.decode_instruction(
          lower_word : UInt32,
          upper_word : UInt32,
          pc : UInt32 = 0_u32,
          base_addr : UInt64 = Registers::VU1_MICRO_MEM,
        ) : VUInstruction
          addr = base_addr + (pc.to_u64 * 8_u64)
          raw = (upper_word.to_u64 << 32) | lower_word.to_u64

          i_bit = ((upper_word >> 31) & 1) == 1
          e_bit = ((upper_word >> 30) & 1) == 1
          m_bit = ((upper_word >> 29) & 1) == 1
          d_bit = ((upper_word >> 28) & 1) == 1
          t_bit = ((upper_word >> 27) & 1) == 1

          flag_suffix = String.build do |io|
            if i_bit || e_bit || m_bit || d_bit || t_bit
              io << '['
              io << 'I' if i_bit
              io << 'E' if e_bit
              io << 'M' if m_bit
              io << 'D' if d_bit
              io << 'T' if t_bit
              io << ']'
            end
          end

          # Decode Upper 32-bit word (FMAC pipeline)
          u_body = upper_word & 0x07FF_FFFF_u32
          dest_mask = ((upper_word >> 21) & 0xF).to_u8
          u_ft = ((upper_word >> 16) & 0x1F).to_u8
          u_fs = ((upper_word >> 11) & 0x1F).to_u8
          u_fd = ((upper_word >> 6) & 0x1F).to_u8
          op6 = (upper_word & 0x3F).to_u8
          op11 = (upper_word & 0x7FF).to_u16

          upper_op = "NOP"
          upper_mnemonic = "NOP#{flag_suffix}"
          writes_acc = false
          reads_acc = false
          reads_q = false
          reads_p = false
          reads_i = false

          if u_body != 0_u32 && u_body != UPPER_NOP_CANONICAL && op11 != 0x2FF_u16
            mask_s = format_dest_mask(dest_mask)
            if (op6 & 0x3C_u8) == 0x3C_u8
              case op11
              when 0x2BC_u16
                upper_op = "ADDA"
                writes_acc = true
                upper_mnemonic = "ADDA.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x23E_u16
                upper_op = "ADDAI"
                writes_acc = true
                reads_i = true
                upper_mnemonic = "ADDAi.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, I"
              when 0x23C_u16
                upper_op = "ADDAQ"
                writes_acc = true
                reads_q = true
                upper_mnemonic = "ADDAq.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, Q"
              when 0x2FC_u16
                upper_op = "SUBA"
                writes_acc = true
                upper_mnemonic = "SUBA.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x27E_u16
                upper_op = "SUBAI"
                writes_acc = true
                reads_i = true
                upper_mnemonic = "SUBAi.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, I"
              when 0x27C_u16
                upper_op = "SUBAQ"
                writes_acc = true
                reads_q = true
                upper_mnemonic = "SUBAq.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, Q"
              when 0x2BD_u16
                upper_op = "MADDA"
                writes_acc = true
                reads_acc = true
                upper_mnemonic = "MADDA.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x23F_u16
                upper_op = "MADDAI"
                writes_acc = true
                reads_acc = true
                reads_i = true
                upper_mnemonic = "MADDAi.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, I"
              when 0x23D_u16
                upper_op = "MADDAQ"
                writes_acc = true
                reads_acc = true
                reads_q = true
                upper_mnemonic = "MADDAq.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, Q"
              when 0x2FD_u16
                upper_op = "MSUBA"
                writes_acc = true
                reads_acc = true
                upper_mnemonic = "MSUBA.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x27F_u16
                upper_op = "MSUBAI"
                writes_acc = true
                reads_acc = true
                reads_i = true
                upper_mnemonic = "MSUBAi.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, I"
              when 0x27D_u16
                upper_op = "MSUBAQ"
                writes_acc = true
                reads_acc = true
                reads_q = true
                upper_mnemonic = "MSUBAq.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, Q"
              when 0x2BE_u16
                upper_op = "MULA"
                writes_acc = true
                upper_mnemonic = "MULA.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x1FE_u16
                upper_op = "MULAI"
                writes_acc = true
                reads_i = true
                upper_mnemonic = "MULAi.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, I"
              when 0x1FC_u16
                if u_ft == 0_u8
                  upper_op = "MULAQ"
                  writes_acc = true
                  reads_q = true
                  upper_mnemonic = "MULAq.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, Q"
                else
                  upper_op = "ITOF15"
                  u_fd = u_ft
                  upper_mnemonic = "ITOF15.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}"
                end
              when 0x2FE_u16
                upper_op = "OPMULA"
                writes_acc = true
                upper_mnemonic = "OPMULA.xyz#{flag_suffix} ACC, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x1FF_u16
                upper_op = "CLIP"
                upper_mnemonic = "CLIPw.xyz#{flag_suffix} #{format_vf(u_fs)}, #{format_vf(u_ft)}w"
              when 0x13D_u16
                upper_op = "FTOI0"
                u_fd = u_ft
                upper_mnemonic = "FTOI0.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}"
              when 0x17D_u16
                upper_op = "FTOI4"
                u_fd = u_ft
                upper_mnemonic = "FTOI4.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}"
              when 0x1BD_u16
                upper_op = "FTOI12"
                u_fd = u_ft
                upper_mnemonic = "FTOI12.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}"
              when 0x1FD_u16
                upper_op = "FTOI15"
                u_fd = u_ft
                upper_mnemonic = "FTOI15.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}"
              when 0x13C_u16
                upper_op = "ITOF0"
                u_fd = u_ft
                upper_mnemonic = "ITOF0.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}"
              when 0x17C_u16
                upper_op = "ITOF4"
                u_fd = u_ft
                upper_mnemonic = "ITOF4.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}"
              else
                bc_s = format_broadcast((op11 & 3).to_u8)
                case op11 & 0x7FC_u16
                when 0x03C_u16
                  upper_op = "ADDABC"
                  writes_acc = true
                  upper_mnemonic = "ADDA#{bc_s}.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
                when 0x07C_u16
                  upper_op = "SUBABC"
                  writes_acc = true
                  upper_mnemonic = "SUBA#{bc_s}.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
                when 0x0BC_u16
                  upper_op = "MADDABC"
                  writes_acc = true
                  reads_acc = true
                  upper_mnemonic = "MADDA#{bc_s}.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
                when 0x0FC_u16
                  upper_op = "MSUBABC"
                  writes_acc = true
                  reads_acc = true
                  upper_mnemonic = "MSUBA#{bc_s}.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
                when 0x1BC_u16
                  upper_op = "MULABC"
                  writes_acc = true
                  upper_mnemonic = "MULA#{bc_s}.#{mask_s}#{flag_suffix} ACC, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
                end
              end
            else
              bc_s = format_broadcast(op6 & 3_u8)
              case op6
              when 0x00_u8..0x03_u8
                upper_op = "ADDBC"
                upper_mnemonic = "ADD#{bc_s}.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x04_u8..0x07_u8
                upper_op = "SUBBC"
                upper_mnemonic = "SUB#{bc_s}.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x08_u8..0x0B_u8
                upper_op = "MADDBC"
                reads_acc = true
                upper_mnemonic = "MADD#{bc_s}.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x0C_u8..0x0F_u8
                upper_op = "MSUBBC"
                reads_acc = true
                upper_mnemonic = "MSUB#{bc_s}.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x10_u8..0x13_u8
                upper_op = "MAXBC"
                upper_mnemonic = "MAX#{bc_s}.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x14_u8..0x17_u8
                upper_op = "MINIBC"
                upper_mnemonic = "MINI#{bc_s}.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x18_u8..0x1B_u8
                upper_op = "MULBC"
                upper_mnemonic = "MUL#{bc_s}.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x1C_u8
                upper_op = "MULQ"
                reads_q = true
                upper_mnemonic = "MULq.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, Q"
              when 0x1D_u8
                upper_op = "MAXI"
                reads_i = true
                upper_mnemonic = "MAXi.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, I"
              when 0x1E_u8
                upper_op = "MULI"
                reads_i = true
                upper_mnemonic = "MULi.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, I"
              when 0x1F_u8
                upper_op = "MINII"
                reads_i = true
                upper_mnemonic = "MINIi.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, I"
              when 0x20_u8
                upper_op = "ADDQ"
                reads_q = true
                upper_mnemonic = "ADDq.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, Q"
              when 0x21_u8
                upper_op = "MADDQ"
                reads_acc = true
                reads_q = true
                upper_mnemonic = "MADDq.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, Q"
              when 0x22_u8
                upper_op = "ADDI"
                reads_i = true
                upper_mnemonic = "ADDi.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, I"
              when 0x23_u8
                upper_op = "MADDI"
                reads_acc = true
                reads_i = true
                upper_mnemonic = "MADDi.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, I"
              when 0x24_u8
                upper_op = "SUBQ"
                reads_q = true
                upper_mnemonic = "SUBq.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, Q"
              when 0x25_u8
                upper_op = "MSUBQ"
                reads_acc = true
                reads_q = true
                upper_mnemonic = "MSUBq.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, Q"
              when 0x26_u8
                upper_op = "SUBI"
                reads_i = true
                upper_mnemonic = "SUBi.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, I"
              when 0x27_u8
                upper_op = "MSUBI"
                reads_acc = true
                reads_i = true
                upper_mnemonic = "MSUBi.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, I"
              when 0x28_u8
                upper_op = "ADD"
                upper_mnemonic = "ADD.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x29_u8
                upper_op = "MADD"
                reads_acc = true
                upper_mnemonic = "MADD.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x2A_u8
                upper_op = "MUL"
                upper_mnemonic = "MUL.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x2B_u8
                upper_op = "MAX"
                upper_mnemonic = "MAX.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x2C_u8
                upper_op = "SUB"
                upper_mnemonic = "SUB.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x2D_u8
                upper_op = "MSUB"
                reads_acc = true
                upper_mnemonic = "MSUB.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x2E_u8
                upper_op = "OPMSUB"
                reads_acc = true
                upper_mnemonic = "OPMSUB.xyz#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              when 0x2F_u8
                upper_op = "MINI"
                upper_mnemonic = "MINI.#{mask_s}#{flag_suffix} #{format_vf(u_fd)}, #{format_vf(u_fs)}, #{format_vf(u_ft)}"
              end
            end
          end

          # Decode Lower 32-bit word (LSU / IALU / FDIV / Branch / XGKICK)
          lower_op = "NOP"
          lower_mnemonic = "NOP"
          l_dest = ((lower_word >> 21) & 0xF).to_u8
          l_ft = ((lower_word >> 16) & 0x1F).to_u8
          l_fs = ((lower_word >> 11) & 0x1F).to_u8
          l_it = ((lower_word >> 16) & 0x0F).to_u8
          l_is = ((lower_word >> 11) & 0x0F).to_u8
          l_id = ((lower_word >> 6) & 0x0F).to_u8
          l_imm = 0
          fdiv_latency = 0

          if i_bit
            lower_op = "LOI"
            fval = lower_word.unsafe_as(Float32)
            lower_mnemonic = "LOI #{fval}"
          elsif lower_word != 0_u32 && lower_word != LOWER_NOP_CANONICAL
            l_mask_s = format_dest_mask(l_dest)
            if (lower_word & 0x80000000_u32) != 0_u32
              low11 = (lower_word & 0x7FF).to_u16
              low6 = (lower_word & 0x3F).to_u8
              if low6 == 0x30_u8
                lower_op = "IADD"
                lower_mnemonic = "IADD #{format_vi(l_id)}, #{format_vi(l_is)}, #{format_vi(l_it)}"
              elsif low6 == 0x31_u8
                lower_op = "ISUB"
                lower_mnemonic = "ISUB #{format_vi(l_id)}, #{format_vi(l_is)}, #{format_vi(l_it)}"
              elsif low6 == 0x32_u8
                lower_op = "IADDI"
                raw5 = ((lower_word >> 6) & 0x1F).to_i32
                l_imm = (raw5 & 0x10) != 0 ? (raw5 - 32) : raw5
                lower_mnemonic = "IADDI #{format_vi(l_it)}, #{format_vi(l_is)}, #{l_imm}"
              elsif low6 == 0x34_u8
                lower_op = "IAND"
                lower_mnemonic = "IAND #{format_vi(l_id)}, #{format_vi(l_is)}, #{format_vi(l_it)}"
              elsif low6 == 0x35_u8
                lower_op = "IOR"
                lower_mnemonic = "IOR #{format_vi(l_id)}, #{format_vi(l_is)}, #{format_vi(l_it)}"
              else
                case low11
                when 0x33C_u16
                  if l_dest != 0_u8 && (l_ft != 0_u8 || l_fs != 0_u8)
                    lower_op = "MOVE"
                    lower_mnemonic = "MOVE.#{l_mask_s} #{format_vf(l_ft)}, #{format_vf(l_fs)}"
                  end
                when 0x33D_u16
                  lower_op = "MR32"
                  lower_mnemonic = "MR32.#{l_mask_s} #{format_vf(l_ft)}, #{format_vf(l_fs)}"
                when 0x37C_u16
                  lower_op = "LQI"
                  lower_mnemonic = "LQI.#{l_mask_s} #{format_vf(l_ft)}, (#{format_vi(l_is)}++)"
                when 0x3FC_u16
                  lower_op = "SQI"
                  lower_mnemonic = "SQI.#{l_mask_s} #{format_vf(l_fs)}, (#{format_vi(l_it)}++)"
                when 0x37E_u16
                  lower_op = "LQD"
                  lower_mnemonic = "LQD.#{l_mask_s} #{format_vf(l_ft)}, (--#{format_vi(l_is)})"
                when 0x3FE_u16
                  lower_op = "SQD"
                  lower_mnemonic = "SQD.#{l_mask_s} #{format_vf(l_fs)}, (--#{format_vi(l_it)})"
                when 0x3BC_u16
                  lower_op = "DIV"
                  fdiv_latency = FDIV_DIV_LATENCY
                  fsf_s = format_broadcast(((lower_word >> 21) & 3).to_u8)
                  ftf_s = format_broadcast(((lower_word >> 23) & 3).to_u8)
                  lower_mnemonic = "DIV Q, #{format_vf(l_fs)}.#{fsf_s}, #{format_vf(l_ft)}.#{ftf_s}"
                when 0x3BD_u16
                  lower_op = "SQRT"
                  fdiv_latency = FDIV_DIV_LATENCY
                  ftf_s = format_broadcast(((lower_word >> 23) & 3).to_u8)
                  lower_mnemonic = "SQRT Q, #{format_vf(l_ft)}.#{ftf_s}"
                when 0x3BE_u16
                  lower_op = "RSQRT"
                  fdiv_latency = FDIV_RSQRT_LATENCY
                  fsf_s = format_broadcast(((lower_word >> 21) & 3).to_u8)
                  ftf_s = format_broadcast(((lower_word >> 23) & 3).to_u8)
                  lower_mnemonic = "RSQRT Q, #{format_vf(l_fs)}.#{fsf_s}, #{format_vf(l_ft)}.#{ftf_s}"
                when 0x3BF_u16
                  lower_op = "WAITQ"
                  lower_mnemonic = "WAITQ"
                when 0x7BF_u16
                  lower_op = "WAITP"
                  lower_mnemonic = "WAITP"
                when 0x3FD_u16
                  lower_op = "MFIR"
                  lower_mnemonic = "MFIR.#{l_mask_s} #{format_vf(l_ft)}, #{format_vi(l_is)}"
                when 0x3FF_u16
                  lower_op = "MTIR"
                  fsf_s = format_broadcast(((lower_word >> 21) & 3).to_u8)
                  lower_mnemonic = "MTIR #{format_vi(l_it)}, #{format_vf(l_fs)}.#{fsf_s}"
                when 0x6BC_u16
                  lower_op = "XTOP"
                  lower_mnemonic = "XTOP #{format_vi(l_it)}"
                when 0x6BD_u16
                  lower_op = "XITOP"
                  lower_mnemonic = "XITOP #{format_vi(l_it)}"
                when 0x6FC_u16
                  lower_op = "XGKICK"
                  lower_mnemonic = "XGKICK #{format_vi(l_is)}"
                end
              end
            else
              top7 = ((lower_word >> 25) & 0x7F).to_u8
              raw11 = (lower_word & 0x7FF).to_i32
              imm11_signed = (raw11 & 0x400) != 0 ? (raw11 - 2048) : raw11
              imm15 = (((lower_word >> 21) & 0xF).to_i32 << 11) | raw11

              case top7
              when 0x00_u8
                lower_op = "LQ"
                l_imm = imm11_signed
                lower_mnemonic = "LQ.#{l_mask_s} #{format_vf(l_ft)}, #{l_imm}(#{format_vi(l_is)})"
              when 0x01_u8
                lower_op = "SQ"
                l_imm = imm11_signed
                lower_mnemonic = "SQ.#{l_mask_s} #{format_vf(l_fs)}, #{l_imm}(#{format_vi(l_it)})"
              when 0x04_u8
                lower_op = "ILW"
                l_imm = imm11_signed
                lower_mnemonic = "ILW.#{l_mask_s} #{format_vi(l_it)}, #{l_imm}(#{format_vi(l_is)})"
              when 0x05_u8
                lower_op = "ISW"
                l_imm = imm11_signed
                lower_mnemonic = "ISW.#{l_mask_s} #{format_vi(l_it)}, #{l_imm}(#{format_vi(l_is)})"
              when 0x08_u8
                lower_op = "IADDIU"
                l_imm = imm15
                lower_mnemonic = "IADDIU #{format_vi(l_it)}, #{format_vi(l_is)}, #{l_imm}"
              when 0x09_u8
                lower_op = "ISUBIU"
                l_imm = imm15
                lower_mnemonic = "ISUBIU #{format_vi(l_it)}, #{format_vi(l_is)}, #{l_imm}"
              when 0x20_u8
                lower_op = "B"
                l_imm = imm11_signed
                lower_mnemonic = "B #{l_imm}"
              when 0x21_u8
                lower_op = "BAL"
                l_imm = imm11_signed
                lower_mnemonic = "BAL #{format_vi(l_it)}, #{l_imm}"
              when 0x24_u8
                lower_op = "JR"
                lower_mnemonic = "JR #{format_vi(l_is)}"
              when 0x25_u8
                lower_op = "JALR"
                lower_mnemonic = "JALR #{format_vi(l_it)}, #{format_vi(l_is)}"
              when 0x28_u8
                lower_op = "IBEQ"
                l_imm = imm11_signed
                lower_mnemonic = "IBEQ #{format_vi(l_it)}, #{format_vi(l_is)}, #{l_imm}"
              when 0x29_u8
                lower_op = "IBNE"
                l_imm = imm11_signed
                lower_mnemonic = "IBNE #{format_vi(l_it)}, #{format_vi(l_is)}, #{l_imm}"
              when 0x2C_u8
                lower_op = "IBLTZ"
                l_imm = imm11_signed
                lower_mnemonic = "IBLTZ #{format_vi(l_is)}, #{l_imm}"
              when 0x2D_u8
                lower_op = "IBGTZ"
                l_imm = imm11_signed
                lower_mnemonic = "IBGTZ #{format_vi(l_is)}, #{l_imm}"
              when 0x2E_u8
                lower_op = "IBLEZ"
                l_imm = imm11_signed
                lower_mnemonic = "IBLEZ #{format_vi(l_is)}, #{l_imm}"
              when 0x2F_u8
                lower_op = "IBGEZ"
                l_imm = imm11_signed
                lower_mnemonic = "IBGEZ #{format_vi(l_is)}, #{l_imm}"
              end
            end
          end

          VUInstruction.new(
            pc: pc,
            address: addr,
            raw: raw,
            upper_word: upper_word,
            lower_word: lower_word,
            upper_op: upper_op,
            lower_op: lower_op,
            upper_mnemonic: upper_mnemonic,
            lower_mnemonic: lower_mnemonic,
            dest_mask: dest_mask,
            lower_dest_mask: l_dest,
            upper_fd: u_fd,
            upper_fs: u_fs,
            upper_ft: u_ft,
            lower_ft: l_ft,
            lower_fs: l_fs,
            lower_id: l_id,
            lower_is: l_is,
            lower_it: l_it,
            lower_imm: l_imm,
            writes_acc: writes_acc,
            reads_acc: reads_acc,
            reads_q: reads_q,
            reads_p: reads_p,
            reads_i: reads_i,
            fdiv_latency: fdiv_latency,
            i_bit: i_bit,
            e_bit: e_bit,
            m_bit: m_bit,
            d_bit: d_bit,
            t_bit: t_bit
          )
        end

        # Decodes a binary slice of 64-bit VU1 microinstructions (8 bytes each, little-endian).
        def decode_microprogram(
          bytes : Bytes,
          start_pc : UInt32 = @start_pc,
          max_instructions : Int32 = @max_instructions,
          stop_on_e_bit : Bool = @stop_on_e_bit,
          base_addr : UInt64 = @micro_base,
        ) : Array(VUInstruction)
          instructions = [] of VUInstruction
          pos = 0
          idx = 0
          stop_after_next = false

          while pos + 8 <= bytes.size && idx < max_instructions
            lower = IO::ByteFormat::LittleEndian.decode(UInt32, bytes[pos, 4])
            upper = IO::ByteFormat::LittleEndian.decode(UInt32, bytes[pos + 4, 4])
            inst = VUProfiler.decode_instruction(lower, upper, start_pc + idx.to_u32, base_addr)
            instructions << inst

            break if stop_after_next
            if stop_on_e_bit && inst.e_bit
              # VU1 [E]-bit has a 1-instruction delay slot before halting
              stop_after_next = true
            end

            pos += 8
            idx += 1
          end

          instructions
        end

        # Analyzes a sequence of decoded `VUInstruction`s for PS2 VU1 pipeline stall hazards and register conflicts.
        def analyze_hazards(
          instructions : Array(VUInstruction),
          xgkick_min_separation : Int32 = @xgkick_min_separation,
        ) : Array(VUStallHazard)
          hazards = [] of VUStallHazard
          pending_q : Tuple(UInt32, Int32, Int32)? = nil # {producer_pc, index, latency}
          last_xgkick : Tuple(UInt32, Int32)? = nil      # {producer_pc, index}

          instructions.each_with_index do |inst, idx|
            # 1. Same-cycle LOI + active Lower conflict
            if inst.i_bit && !inst.lower_nop?
              hazards << VUStallHazard.new(
                pc: inst.pc,
                address: inst.address,
                producer_pc: inst.pc,
                hazard_type: HazardType::LoiLowerConflict,
                severity: HazardSeverity::Error,
                register: "I",
                stall_cycles: 0,
                description: "Upper sets I-bit (LOI) while Lower encodes #{inst.lower_op} at PC #{inst.pc}"
              )
            end

            # 2. Same-cycle VF write-after-write conflict
            if inst.upper_writes_vf? && inst.lower_writes_vf? && inst.upper_fd == inst.lower_ft
              overlap = inst.dest_mask & inst.lower_dest_mask
              if overlap != 0_u8
                reg_str = "#{VUProfiler.format_vf(inst.upper_fd)}.#{VUProfiler.format_dest_mask(overlap)}"
                hazards << VUStallHazard.new(
                  pc: inst.pc,
                  address: inst.address,
                  producer_pc: inst.pc,
                  hazard_type: HazardType::SameCycleVfWrite,
                  severity: HazardSeverity::Error,
                  register: reg_str,
                  stall_cycles: 0,
                  description: "Dual-issue write conflict on #{reg_str} between Upper #{inst.upper_op} and Lower #{inst.lower_op}"
                )
              end
            end

            # 3. Branch inside delay slot of previous branch or [E]-bit
            if idx > 0
              prev = instructions[idx - 1]
              if inst.branch? && (prev.branch? || prev.e_bit)
                hazards << VUStallHazard.new(
                  pc: inst.pc,
                  address: inst.address,
                  producer_pc: prev.pc,
                  hazard_type: HazardType::BranchDelaySlot,
                  severity: HazardSeverity::Error,
                  register: "PC",
                  stall_cycles: 0,
                  description: "Branch #{inst.lower_op} at PC #{inst.pc} is inside the delay slot of PC #{prev.pc}"
                )
              end
            end

            # 4. VI -> Branch 1-cycle hazard (no hardware interlock on PS2 VU1)
            if inst.branch? && idx > 0
              prev = instructions[idx - 1]
              vi_written = prev.lower_vi_dest
              if vi_written != 0_u8
                reads_is = (inst.lower_op != "B" && inst.lower_op != "BAL") && inst.lower_is == vi_written
                reads_it = (inst.lower_op == "IBEQ" || inst.lower_op == "IBNE") && inst.lower_it == vi_written
                if reads_is || reads_it
                  reg_str = VUProfiler.format_vi(vi_written)
                  hazards << VUStallHazard.new(
                    pc: inst.pc,
                    address: inst.address,
                    producer_pc: prev.pc,
                    hazard_type: HazardType::IaluBranch,
                    severity: HazardSeverity::Error,
                    register: reg_str,
                    stall_cycles: 1,
                    description: "VI branch hazard on #{reg_str}: written by #{prev.lower_op} at PC #{prev.pc} and read by #{inst.lower_op} at PC #{inst.pc} without 1-cycle NOP"
                  )
                end
              end
            end

            # 5. ILW 4-cycle integer load hazard
            (1...ILW_LATENCY).each do |delta|
              break if idx - delta < 0
              prod = instructions[idx - delta]
              if prod.lower_op == "ILW" && prod.lower_vi_dest != 0_u8
                vi_reg = prod.lower_vi_dest
                reads_vi = (!inst.lower_nop? && inst.lower_is == vi_reg) ||
                           (inst.lower_it == vi_reg && (inst.lower_op == "IADD" || inst.lower_op == "ISUB" || inst.lower_op == "IAND" || inst.lower_op == "IOR" || inst.lower_op == "IBEQ" || inst.lower_op == "IBNE"))
                if reads_vi
                  stall = ILW_LATENCY - delta
                  reg_str = VUProfiler.format_vi(vi_reg)
                  hazards << VUStallHazard.new(
                    pc: inst.pc,
                    address: inst.address,
                    producer_pc: prod.pc,
                    hazard_type: HazardType::IlwLoadRaw,
                    severity: HazardSeverity::Warning,
                    register: reg_str,
                    stall_cycles: stall,
                    description: "ILW load latency stall (#{stall} cycle(s)) on #{reg_str} from PC #{prod.pc}"
                  )
                  break
                end
              end
            end

            # 6. FMAC 4-cycle RAW pipeline stall & FMAC -> Store stall & Load-to-Use (LQ -> FMAC) stall
            (1...FMAC_LATENCY).each do |delta|
              break if idx - delta < 0
              prod = instructions[idx - delta]

              # 6a. Producer is Upper FMAC writing VF
              if prod.upper_writes_vf?
                prod_vf = prod.upper_fd
                prod_mask = prod.dest_mask
                reads_in_u = (inst.upper_reads_fs? && inst.upper_fs == prod_vf) ||
                             (inst.upper_reads_ft? && inst.upper_ft == prod_vf)
                reads_in_l = (inst.lower_reads_vf_fs? && inst.lower_fs == prod_vf && ((inst.lower_dest_mask & prod_mask) != 0_u8 || inst.fdiv_latency > 0)) ||
                             (inst.lower_reads_vf_ft? && inst.lower_ft == prod_vf)

                if reads_in_u || reads_in_l
                  stall = FMAC_LATENCY - delta
                  reg_str = "#{VUProfiler.format_vf(prod_vf)}.#{VUProfiler.format_dest_mask(prod_mask)}"
                  htype = (!reads_in_u && (inst.lower_op == "SQ" || inst.lower_op == "SQI" || inst.lower_op == "SQD")) ? HazardType::FmacStore : HazardType::FmacRaw
                  hazards << VUStallHazard.new(
                    pc: inst.pc,
                    address: inst.address,
                    producer_pc: prod.pc,
                    hazard_type: htype,
                    severity: HazardSeverity::Warning,
                    register: reg_str,
                    stall_cycles: stall,
                    description: "FMAC RAW interlock stall (#{stall} cycle(s)) on #{reg_str} produced by #{prod.upper_op} at PC #{prod.pc}"
                  )
                  break
                end
              end

              # 6b. Producer is Lower LQ/LQI/LQD loading VF and read by Upper FMAC
              if prod.lower_loads_vf?
                load_vf = prod.lower_ft
                load_mask = prod.lower_dest_mask
                reads_in_u = (inst.upper_reads_fs? && inst.upper_fs == load_vf) ||
                             (inst.upper_reads_ft? && inst.upper_ft == load_vf)
                if reads_in_u
                  stall = LOAD_LATENCY - delta
                  reg_str = "#{VUProfiler.format_vf(load_vf)}.#{VUProfiler.format_dest_mask(load_mask)}"
                  hazards << VUStallHazard.new(
                    pc: inst.pc,
                    address: inst.address,
                    producer_pc: prod.pc,
                    hazard_type: HazardType::LoadUse,
                    severity: HazardSeverity::Warning,
                    register: reg_str,
                    stall_cycles: stall,
                    description: "VU1 memory load-to-use stall (#{stall} cycle(s)) on #{reg_str} loaded by #{prod.lower_op} at PC #{prod.pc}"
                  )
                  break
                end
              end
            end

            # 7. FDIV / SQRT / RSQRT Q-register wait and unwaited Q read hazards
            if inst.waitq?
              if pq = pending_q
                elapsed = idx - pq[1]
                if elapsed < pq[2]
                  stall = pq[2] - elapsed
                  hazards << VUStallHazard.new(
                    pc: inst.pc,
                    address: inst.address,
                    producer_pc: pq[0],
                    hazard_type: HazardType::FdivWait,
                    severity: HazardSeverity::Warning,
                    register: "Q",
                    stall_cycles: stall,
                    description: "WAITQ stalls #{stall} cycle(s) awaiting FDIV/SQRT started at PC #{pq[0]}"
                  )
                end
                pending_q = nil
              end
            end

            if inst.reads_q
              if pq = pending_q
                elapsed = idx - pq[1]
                if elapsed < pq[2]
                  rem = pq[2] - elapsed
                  hazards << VUStallHazard.new(
                    pc: inst.pc,
                    address: inst.address,
                    producer_pc: pq[0],
                    hazard_type: HazardType::FdivWait,
                    severity: HazardSeverity::Error,
                    register: "Q",
                    stall_cycles: rem,
                    description: "Upper #{inst.upper_op} reads Q register #{elapsed} cycle(s) after FDIV at PC #{pq[0]} without WAITQ (#{rem} cycle(s) early)"
                  )
                end
                pending_q = nil
              end
            end

            if inst.fdiv_latency > 0
              pending_q = {inst.pc, idx, inst.fdiv_latency}
            end

            # 8. Back-to-back XGKICK GIF Path 1 stall check
            if inst.xgkick?
              if prev_k = last_xgkick
                elapsed = idx - prev_k[1]
                if elapsed < xgkick_min_separation
                  stall = xgkick_min_separation - elapsed
                  hazards << VUStallHazard.new(
                    pc: inst.pc,
                    address: inst.address,
                    producer_pc: prev_k[0],
                    hazard_type: HazardType::XgkickStall,
                    severity: HazardSeverity::Warning,
                    register: "GIF_PATH1",
                    stall_cycles: stall,
                    description: "Back-to-back XGKICK at PC #{inst.pc} within #{elapsed} cycle(s) of PC #{prev_k[0]} stalls VU1 on GIF Path 1"
                  )
                end
              end
              last_xgkick = {inst.pc, idx}
            end
          end

          hazards
        end

        # Profiles a binary slice of VU1 micro-memory instructions and computes cycle counts, stalls, IPC, and frame budgets.
        def profile_bytes(
          micro_bytes : Bytes,
          start_pc : UInt32 = @start_pc,
          max_instructions : Int32 = @max_instructions,
          stop_on_e_bit : Bool = @stop_on_e_bit,
        ) : VUProfileReport
          start_addr = @micro_base + (start_pc.to_u64 * 8_u64)
          insts = decode_microprogram(micro_bytes, start_pc, max_instructions, stop_on_e_bit, @micro_base)
          hazards = analyze_hazards(insts, @xgkick_min_separation)

          inst_count = insts.size
          dual_count = insts.count(&.dual_issued?)
          active_ops = insts.sum do |i|
            ops = 0
            ops += 1 unless i.upper_nop?
            ops += 1 unless i.lower_nop?
            ops
          end
          xgkicks = insts.count(&.xgkick?)
          terminated = insts.any?(&.e_bit)

          base_cyc = inst_count
          stall_cyc = hazards.sum(&.stall_cycles)
          total_cyc = base_cyc + stall_cyc
          ee_cyc = total_cyc * 2

          ipc_val = total_cyc > 0 ? (active_ops.to_f64 / total_cyc.to_f64) : 0.0
          dual_ratio = inst_count > 0 ? (dual_count.to_f64 / inst_count.to_f64) : 0.0
          ntsc_pct = (total_cyc.to_f64 / Registers::NTSC_VU1_CYCLES.to_f64) * 100.0
          pal_pct = (total_cyc.to_f64 / Registers::PAL_VU1_CYCLES.to_f64) * 100.0

          VUProfileReport.new(
            start_address: start_addr,
            instruction_count: inst_count,
            active_op_count: active_ops,
            dual_issue_count: dual_count,
            base_cycles: base_cyc,
            stall_cycles: stall_cyc,
            total_cycles: total_cyc,
            ee_equivalent_cycles: ee_cyc,
            ipc: ipc_val,
            dual_issue_ratio: dual_ratio,
            ntsc_frame_budget_pct: ntsc_pct,
            pal_frame_budget_pct: pal_pct,
            terminated_by_e_bit: terminated,
            xgkick_count: xgkicks,
            instructions: insts,
            hazards: hazards
          )
        end

        # Reads VU1 Micro-Memory (`0x11008000`) over r2pipe/GDB and profiles the microprogram.
        def profile(
          start_pc : UInt32 = @start_pc,
          max_instructions : Int32 = @max_instructions,
        ) : VUProfileReport
          byte_offset = (start_pc * 8_u32).to_i32
          byte_len = max_instructions * 8
          raw = read_micro_memory(byte_offset, byte_len)
          profile_bytes(raw, start_pc, max_instructions, @stop_on_e_bit)
        end

        # Decodes a slice of bytes into 128-bit `VUQuadword` entries (`x, y, z, w` floats & `ix, iy, iz, iw` uint32s).
        def decode_quadwords(
          bytes : Bytes,
          qw_offset : Int32 = 0,
          base_addr : UInt64 = @data_base,
        ) : Array(VUQuadword)
          quads = [] of VUQuadword
          pos = 0
          idx = 0
          while pos + 16 <= bytes.size
            ix = IO::ByteFormat::LittleEndian.decode(UInt32, bytes[pos, 4])
            iy = IO::ByteFormat::LittleEndian.decode(UInt32, bytes[pos + 4, 4])
            iz = IO::ByteFormat::LittleEndian.decode(UInt32, bytes[pos + 8, 4])
            iw = IO::ByteFormat::LittleEndian.decode(UInt32, bytes[pos + 12, 4])

            fx = ix.unsafe_as(Float32)
            fy = iy.unsafe_as(Float32)
            fz = iz.unsafe_as(Float32)
            fw = iw.unsafe_as(Float32)

            q_idx = (qw_offset + idx).to_u32
            q_addr = base_addr + (q_idx.to_u64 * 16_u64)
            quads << VUQuadword.new(q_idx, q_addr, fx, fy, fz, fw, ix, iy, iz, iw)
            pos += 16
            idx += 1
          end
          quads
        end

        # Inspects VU1 Data Memory (`0x1100C000`), VIF1 double-buffer registers, and EE timers over r2pipe/GDB.
        def inspect_data_memory(
          qw_offset : Int32 = @data_qw_offset,
          qw_count : Int32 = @data_qw_count,
        ) : VUMemorySnapshot
          byte_offset = qw_offset * 16
          byte_len = qw_count * 16
          raw = read_data_memory(byte_offset, byte_len)
          quads = decode_quadwords(raw, qw_offset, @data_base)

          stat = read_u32(Registers::VIF1_STAT)
          top = read_u32(Registers::VIF1_TOP)
          tops = read_u32(Registers::VIF1_TOPS)
          itop = read_u32(Registers::VIF1_ITOP)
          t0 = read_u32(Registers::EE_T0_COUNT)
          t1 = read_u32(Registers::EE_T1_COUNT)

          VUMemorySnapshot.new(
            base_address: @data_base + byte_offset.to_u64,
            quadwords: quads,
            vif1_stat: stat,
            vif1_top: top,
            vif1_tops: tops,
            vif1_itop: itop,
            ee_timer0: t0,
            ee_timer1: t1
          )
        end

        # Dissects a GS GIF packet prepared for `XGKICK` at quadword offset `qw_offset` in VU1 Data Memory (`0x1100C000`).
        def dissect_xgkick_packet(qw_offset : Int32, max_items : Int32 = 32) : Array(GifDissector::GifItemInfo)
          addr = @data_base + (qw_offset.to_u64 * 16_u64)
          tag_bytes = read_bytes(addr, 16)
          return [] of GifDissector::GifItemInfo if tag_bytes.size < 16

          tag = GifDissector.decode_giftag(tag_bytes)
          total_items = Math.min(tag.nloop.to_i32, max_items)
          packet_bytes = read_bytes(addr, 16 + total_items * 16)
          GifDissector.dissect_packet(packet_bytes, max_items)
        end
      end
    end
  end

  # Expose `Cradare2::PS2` top-level namespace aliasing `Cradare2::Platform::PS2` for ergonomic access
  module PS2
    alias Registers = Platform::PS2::Registers
    alias GifDissector = Platform::PS2::GifDissector
    alias Helper = Platform::PS2::Helper
    alias HazardType = Platform::PS2::HazardType
    alias HazardSeverity = Platform::PS2::HazardSeverity
    alias VUInstruction = Platform::PS2::VUInstruction
    alias VUStallHazard = Platform::PS2::VUStallHazard
    alias VUQuadword = Platform::PS2::VUQuadword
    alias VUMemorySnapshot = Platform::PS2::VUMemorySnapshot
    alias VUProfileReport = Platform::PS2::VUProfileReport
    alias VUProfiler = Platform::PS2::VUProfiler
  end

  # =========================================================================
  # Tier 2: Declarative Builder DSL
  # =========================================================================

  # Declarative block DSL for configuring and executing a PS2 VU1 cycle & hazard profile over r2pipe.
  def self.vu_profiler(client : Client, &block : PS2::VUProfiler ->) : PS2::VUProfileReport
    profiler = PS2::VUProfiler.new(client)
    yield profiler
    profiler.profile
  end

  # Declarative block DSL for configuring and executing a PS2 VU1 cycle & hazard profile over GDB RSP.
  def self.vu_profiler(gdb : Gdb::Client, &block : PS2::VUProfiler ->) : PS2::VUProfileReport
    profiler = PS2::VUProfiler.new(gdb)
    yield profiler
    profiler.profile
  end

  # Declarative block DSL for configuring and executing an offline PS2 VU1 cycle & hazard profile from byte slices.
  def self.vu_profiler(micro_bytes : Bytes = Bytes.empty, data_bytes : Bytes = Bytes.empty, &block : PS2::VUProfiler ->) : PS2::VUProfileReport
    profiler = PS2::VUProfiler.new(micro_bytes, data_bytes)
    yield profiler
    profiler.profile
  end
end

class Cradare2::Gdb::Client
  # Access the PlayStation 2 VU1 memory and cycle profiler over this GDB RSP session.
  def vu_profiler : Cradare2::PS2::VUProfiler
    Cradare2::PS2::VUProfiler.new(self)
  end

  # Profiles VU1 Micro-Memory (`0x11008000`) directly over GDB RSP.
  def profile_vu1(start_pc : UInt32 = 0_u32, max_instructions : Int32 = 256) : Cradare2::PS2::VUProfileReport
    vu_profiler.profile(start_pc, max_instructions)
  end

  # Declarative block receiver for VU1 profiling over GDB RSP.
  def profile_vu1(&block : Cradare2::PS2::VUProfiler ->) : Cradare2::PS2::VUProfileReport
    prof = vu_profiler
    yield prof
    prof.profile
  end
end
